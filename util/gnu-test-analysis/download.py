#!/usr/bin/env python3
"""
GitHub Actions Artifact Downloader and Statistics Generator for GNU Tests

This script downloads artifacts from the GnuTests.yml workflow runs and generates
comprehensive statistics from the aggregated test results.

Usage:
    python download-gnu-test-artifacts.py [options]

Options:
    --token TOKEN         GitHub token for API access (can also use GITHUB_TOKEN env var)
    --repo REPO          Repository in format owner/repo (default: uutils/coreutils)
    --workflow WORKFLOW  Workflow filename (default: GnuTests.yml)
    --limit LIMIT        Number of workflow runs to process (default: 10)
    --output-dir DIR     Directory to store downloaded artifacts (default: ./artifacts)
    --stats-file FILE    Output file for statistics (default: ./gnu-test-statistics.json)
    --verbose            Enable verbose output

Requirements:
    pip install requests
"""

import argparse
import json
import os
import sys
import tempfile
import zipfile
from collections import defaultdict, Counter
from datetime import datetime
from pathlib import Path

try:
    import requests
except ImportError:
    print("Error: 'requests' module is required but not installed.")
    print("Install it with: pip install requests")
    print("Or install all requirements: pip install -r util/gnu-test-analysis/requirements.txt")
    sys.exit(1)


class GitHubArtifactDownloader:
    def __init__(self, token, repo="uutils/coreutils", base_url="https://api.github.com"):
        self.token = token
        self.repo = repo
        self.base_url = base_url
        self.session = requests.Session()
        self.session.headers.update({
            'Authorization': f'token {token}',
            'Accept': 'application/vnd.github.v3+json',
            'User-Agent': 'gnu-test-artifact-downloader'
        })

    def get_workflow_runs(self, workflow_file, limit=10):
        """Get recent workflow runs for the specified workflow."""
        url = f"{self.base_url}/repos/{self.repo}/actions/workflows/{workflow_file}/runs"
        params = {
            'status': 'completed',
            'per_page': min(limit, 100),
            'page': 1
        }

        runs = []
        while len(runs) < limit:
            response = self.session.get(url, params=params)
            response.raise_for_status()

            data = response.json()
            batch_runs = data.get('workflow_runs', [])

            if not batch_runs:
                break

            runs.extend(batch_runs[:limit - len(runs)])

            if len(batch_runs) < params['per_page']:
                break

            params['page'] += 1

        return runs[:limit]

    def get_run_artifacts(self, run_id):
        """Get artifacts for a specific workflow run."""
        url = f"{self.base_url}/repos/{self.repo}/actions/runs/{run_id}/artifacts"
        response = self.session.get(url)
        response.raise_for_status()
        return response.json().get('artifacts', [])

    def download_artifact(self, artifact_url, output_path):
        """Download and extract an artifact."""
        response = self.session.get(artifact_url)
        response.raise_for_status()

        # Create output directory if it doesn't exist
        output_path.parent.mkdir(parents=True, exist_ok=True)

        # Download to temporary file first
        with tempfile.NamedTemporaryFile(delete=False) as temp_file:
            temp_file.write(response.content)
            temp_path = temp_file.name

        try:
            # Extract the zip file
            with zipfile.ZipFile(temp_path, 'r') as zip_ref:
                zip_ref.extractall(output_path)
        finally:
            os.unlink(temp_path)

    def process_workflow_runs(self, workflow_file, limit, output_dir, verbose=False):
        """Process workflow runs and download aggregated-result artifacts."""
        print(f"Fetching {limit} recent workflow runs for {workflow_file}...")
        runs = self.get_workflow_runs(workflow_file, limit)

        downloaded_artifacts = []

        for i, run in enumerate(runs, 1):
            run_id = run['id']
            run_number = run['run_number']
            run_date = run['created_at']
            conclusion = run['conclusion']
            branch = run['head_branch']
            commit_sha = run['head_sha'][:8]

            if verbose:
                print(f"Processing run #{run_number} (ID: {run_id}) - {conclusion} on {branch} ({commit_sha})")
            else:
                print(f"Processing run {i}/{len(runs)}: #{run_number} ({conclusion})")

            # Get artifacts for this run
            artifacts = self.get_run_artifacts(run_id)

            # Look for aggregated-result artifact
            aggregated_artifact = None
            for artifact in artifacts:
                if artifact['name'] == 'aggregated-result':
                    aggregated_artifact = artifact
                    break

            if not aggregated_artifact:
                if verbose:
                    print(f"  No aggregated-result artifact found for run #{run_number}")
                continue

            # Download the artifact
            artifact_dir = output_dir / f"run-{run_number}-{commit_sha}"
            try:
                self.download_artifact(aggregated_artifact['archive_download_url'], artifact_dir)

                # Check if aggregated-result.json exists
                json_file = artifact_dir / 'aggregated-result.json'
                if json_file.exists():
                    downloaded_artifacts.append({
                        'run_number': run_number,
                        'run_id': run_id,
                        'date': run_date,
                        'conclusion': conclusion,
                        'branch': branch,
                        'commit_sha': commit_sha,
                        'file_path': json_file,
                        'artifact_dir': artifact_dir
                    })
                    if verbose:
                        print(f"  Downloaded and extracted to {artifact_dir}")
                else:
                    if verbose:
                        print(f"  Warning: aggregated-result.json not found in artifact")

            except Exception as e:
                print(f"  Error downloading artifact for run #{run_number}: {e}")
                continue

        return downloaded_artifacts


class GnuTestStatisticsGenerator:
    def __init__(self):
        self.reset_stats()

    def reset_stats(self):
        """Reset all statistics counters."""
        self.runs_processed = 0
        self.total_stats = Counter()
        self.per_run_stats = []
        self.per_utility_stats = defaultdict(lambda: defaultdict(int))
        self.test_status_history = defaultdict(list)
        self.failure_frequency = defaultdict(int)
        self.success_rate_per_utility = defaultdict(list)

    def analyze_test_results(self, json_file_path, run_info):
        """Analyze a single aggregated-result.json file."""
        try:
            with open(json_file_path, 'r') as f:
                data = json.load(f)
        except (json.JSONDecodeError, FileNotFoundError) as e:
            print(f"Error reading {json_file_path}: {e}")
            return False

        run_stats = {
            'run_number': run_info['run_number'],
            'date': run_info['date'],
            'conclusion': run_info['conclusion'],
            'branch': run_info['branch'],
            'commit_sha': run_info['commit_sha'],
            'total': 0,
            'pass': 0,
            'fail': 0,
            'skip': 0,
            'error': 0,
            'utilities': {}
        }

        # Analyze each utility's tests
        for utility, tests in data.items():
            utility_stats = Counter()

            for test_name, result in tests.items():
                # Update overall counters
                run_stats['total'] += 1
                self.total_stats[result] += 1

                # Update run stats
                if result == 'PASS':
                    run_stats['pass'] += 1
                elif result == 'FAIL':
                    run_stats['fail'] += 1
                elif result == 'SKIP':
                    run_stats['skip'] += 1
                elif result == 'ERROR':
                    run_stats['error'] += 1

                # Update utility stats
                utility_stats[result] += 1
                self.per_utility_stats[utility][result] += 1

                # Track test status history
                full_test_name = f"{utility}::{test_name}"
                self.test_status_history[full_test_name].append({
                    'run_number': run_info['run_number'],
                    'date': run_info['date'],
                    'result': result
                })

                # Track failure frequency
                if result in ['FAIL', 'ERROR']:
                    self.failure_frequency[full_test_name] += 1

            # Calculate utility success rate for this run
            utility_total = sum(utility_stats.values())
            if utility_total > 0:
                utility_success_rate = utility_stats['PASS'] / utility_total * 100
                self.success_rate_per_utility[utility].append(utility_success_rate)

                run_stats['utilities'][utility] = {
                    'total': utility_total,
                    'pass': utility_stats['PASS'],
                    'fail': utility_stats['FAIL'],
                    'skip': utility_stats['SKIP'],
                    'error': utility_stats['ERROR'],
                    'success_rate': utility_success_rate
                }

        self.per_run_stats.append(run_stats)
        self.runs_processed += 1
        return True

    def generate_statistics(self):
        """Generate comprehensive statistics from all processed runs."""
        if self.runs_processed == 0:
            return {"error": "No runs processed"}

        # Calculate overall statistics
        total_tests = sum(self.total_stats.values())
        overall_success_rate = (self.total_stats['PASS'] / total_tests * 100) if total_tests > 0 else 0

        # Calculate per-utility statistics
        utility_summary = {}
        for utility, stats in self.per_utility_stats.items():
            util_total = sum(stats.values())
            if util_total > 0:
                success_rates = self.success_rate_per_utility[utility]
                utility_summary[utility] = {
                    'total_tests': util_total,
                    'pass': stats['PASS'],
                    'fail': stats['FAIL'],
                    'skip': stats['SKIP'],
                    'error': stats['ERROR'],
                    'overall_success_rate': stats['PASS'] / util_total * 100,
                    'avg_success_rate': sum(success_rates) / len(success_rates) if success_rates else 0,
                    'min_success_rate': min(success_rates) if success_rates else 0,
                    'max_success_rate': max(success_rates) if success_rates else 0
                }

        # Find most problematic tests
        most_failing_tests = sorted(
            self.failure_frequency.items(),
            key=lambda x: x[1],
            reverse=True
        )[:20]

        # Find flaky tests (tests that change status frequently)
        flaky_tests = []
        for test_name, history in self.test_status_history.items():
            if len(history) >= 3:  # Need at least 3 data points
                results = [h['result'] for h in history]
                unique_results = set(results)
                if len(unique_results) > 1:  # Test has multiple different results
                    # Calculate how often it changes
                    changes = sum(1 for i in range(1, len(results)) if results[i] != results[i-1])
                    flaky_score = changes / (len(results) - 1) if len(results) > 1 else 0
                    if flaky_score > 0.3:  # More than 30% of transitions are changes
                        flaky_tests.append({
                            'test': test_name,
                            'flaky_score': flaky_score,
                            'results': results[-10:],  # Last 10 results
                            'total_runs': len(history)
                        })

        flaky_tests.sort(key=lambda x: x['flaky_score'], reverse=True)

        # Generate trend analysis (success rate over time)
        trend_data = []
        for run_stat in sorted(self.per_run_stats, key=lambda x: x['date']):
            if run_stat['total'] > 0:
                success_rate = run_stat['pass'] / run_stat['total'] * 100
                trend_data.append({
                    'run_number': run_stat['run_number'],
                    'date': run_stat['date'],
                    'success_rate': success_rate,
                    'total_tests': run_stat['total']
                })

        return {
            'metadata': {
                'generated_at': datetime.now().isoformat(),
                'runs_analyzed': self.runs_processed,
                'total_test_executions': total_tests
            },
            'overall_statistics': {
                'total_tests': total_tests,
                'pass': self.total_stats['PASS'],
                'fail': self.total_stats['FAIL'],
                'skip': self.total_stats['SKIP'],
                'error': self.total_stats['ERROR'],
                'overall_success_rate': overall_success_rate,
                'failure_rate': (self.total_stats['FAIL'] + self.total_stats['ERROR']) / total_tests * 100 if total_tests > 0 else 0
            },
            'per_utility_statistics': utility_summary,
            'per_run_statistics': self.per_run_stats,
            'trend_analysis': trend_data,
            'most_failing_tests': [{'test': test, 'failure_count': count} for test, count in most_failing_tests],
            'flaky_tests': flaky_tests[:10],  # Top 10 flaky tests
            'test_status_history': dict(self.test_status_history)  # Full history for detailed analysis
        }


def main():
    parser = argparse.ArgumentParser(
        description='Download GitHub Actions artifacts and generate GNU test statistics',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=__doc__
    )

    parser.add_argument('--token', help='GitHub token (or set GITHUB_TOKEN env var)')
    parser.add_argument('--repo', default='uutils/coreutils', help='Repository (owner/repo)')
    parser.add_argument('--workflow', default='GnuTests.yml', help='Workflow filename')
    parser.add_argument('--limit', type=int, default=10, help='Number of runs to process')
    parser.add_argument('--output-dir', type=Path, default='./artifacts', help='Artifact download directory')
    parser.add_argument('--stats-file', type=Path, default='./gnu-test-statistics.json', help='Statistics output file')
    parser.add_argument('--verbose', action='store_true', help='Enable verbose output')

    args = parser.parse_args()

    # Get GitHub token
    token = args.token or os.environ.get('GITHUB_TOKEN')
    if not token:
        print("Error: GitHub token required. Use --token or set GITHUB_TOKEN environment variable.")
        sys.exit(1)

    try:
        # Initialize downloader and download artifacts
        downloader = GitHubArtifactDownloader(token, args.repo)
        artifacts = downloader.process_workflow_runs(
            args.workflow, args.limit, args.output_dir, args.verbose
        )

        if not artifacts:
            print("No artifacts downloaded. Exiting.")
            sys.exit(1)

        print(f"\nDownloaded {len(artifacts)} artifacts. Generating statistics...")

        # Generate statistics
        stats_generator = GnuTestStatisticsGenerator()

        for artifact in artifacts:
            if args.verbose:
                print(f"Analyzing run #{artifact['run_number']}...")
            stats_generator.analyze_test_results(artifact['file_path'], artifact)

        # Generate final statistics
        statistics = stats_generator.generate_statistics()

        # Save statistics to file
        with open(args.stats_file, 'w') as f:
            json.dump(statistics, f, indent=2)

        print(f"\nStatistics saved to {args.stats_file}")

        # Print summary
        overall = statistics['overall_statistics']
        print(f"\n=== GNU Test Statistics Summary ===")
        print(f"Runs analyzed: {statistics['metadata']['runs_analyzed']}")
        print(f"Total test executions: {overall['total_tests']}")
        print(f"Overall success rate: {overall['overall_success_rate']:.2f}%")
        print(f"Pass: {overall['pass']} | Fail: {overall['fail']} | Skip: {overall['skip']} | Error: {overall['error']}")

        if statistics['most_failing_tests']:
            print(f"\nTop 5 most failing tests:")
            for i, test_info in enumerate(statistics['most_failing_tests'][:5], 1):
                print(f"  {i}. {test_info['test']} ({test_info['failure_count']} failures)")

        if statistics['flaky_tests']:
            print(f"\nTop 3 flaky tests:")
            for i, test_info in enumerate(statistics['flaky_tests'][:3], 1):
                print(f"  {i}. {test_info['test']} (flaky score: {test_info['flaky_score']:.2f})")

        print(f"\nDetailed statistics available in {args.stats_file}")

    except KeyboardInterrupt:
        print("\nInterrupted by user.")
        sys.exit(1)
    except Exception as e:
        print(f"Error: {e}")
        if args.verbose:
            import traceback
            traceback.print_exc()
        sys.exit(1)


if __name__ == '__main__':
    main()

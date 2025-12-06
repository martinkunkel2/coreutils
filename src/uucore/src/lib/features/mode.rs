// This file is part of the uutils coreutils package.
//
// For the full copyright and license information, please view the LICENSE
// file that was distributed with this source code.

//! Set of functions to parse modes

// spell-checker:ignore (vars) fperm srwx

use libc::umask;

pub fn parse_numeric(fperm: u32, mut mode: &str, considering_dir: bool) -> Result<u32, String> {
    let (op, pos) = parse_op(mode).map_or_else(|_| (None, 0), |(op, pos)| (Some(op), pos));
    mode = mode[pos..].trim();
    let change = if mode.is_empty() {
        0
    } else {
        u32::from_str_radix(mode, 8).map_err(|e| e.to_string())?
    };
    if change > 0o7777 {
        Err(format!("mode is too large ({change} > 7777"))
    } else {
        Ok(match op {
            Some('+') => fperm | change,
            Some('-') => fperm & !change,
            // If this is a directory, we keep the setgid and setuid bits,
            // unless the mode contains 5 or more octal digits or the mode is "="
            None if considering_dir && mode.len() < 5 => change | (fperm & (0o4000 | 0o2000)),
            None | Some('=') => change,
            Some(_) => unreachable!(),
        })
    }
}

pub fn parse_symbolic(
    mut fperm: u32,
    mut mode: &str,
    umask: u32,
    considering_dir: bool,
) -> Result<u32, String> {
    let (mask, pos) = parse_levels(mode);
    if pos == mode.len() {
        return Err(format!("invalid mode ({mode})"));
    }
    let respect_umask = pos == 0;
    mode = &mode[pos..];
    while !mode.is_empty() {
        let (op, pos) = parse_op(mode)?;
        mode = &mode[pos..];
        let (mut srwx, pos) = parse_change(mode, fperm, considering_dir);
        if respect_umask {
            srwx &= !umask;
        }
        mode = &mode[pos..];
        match op {
            '+' => fperm |= srwx & mask,
            '-' => fperm &= !(srwx & mask),
            '=' => {
                if considering_dir {
                    // keep the setgid and setuid bits for directories
                    srwx |= fperm & (0o4000 | 0o2000);
                }
                fperm = (fperm & !mask) | (srwx & mask);
            }
            _ => unreachable!(),
        }
    }
    Ok(fperm)
}

fn parse_levels(mode: &str) -> (u32, usize) {
    let mut mask = 0;
    let mut pos = 0;
    for ch in mode.chars() {
        mask |= match ch {
            'u' => 0o4700,
            'g' => 0o2070,
            'o' => 0o1007,
            'a' => 0o7777,
            _ => break,
        };
        pos += 1;
    }
    if pos == 0 {
        mask = 0o7777; // default to 'a'
    }
    (mask, pos)
}

fn parse_op(mode: &str) -> Result<(char, usize), String> {
    let ch = mode
        .chars()
        .next()
        .ok_or_else(|| "unexpected end of mode".to_owned())?;
    match ch {
        '+' | '-' | '=' => Ok((ch, 1)),
        _ => Err(format!(
            "invalid operator (expected +, -, or =, but found {ch})"
        )),
    }
}

fn parse_change(mode: &str, fperm: u32, considering_dir: bool) -> (u32, usize) {
    let mut srwx = 0;
    let mut pos = 0;
    for ch in mode.chars() {
        match ch {
            'r' => srwx |= 0o444,
            'w' => srwx |= 0o222,
            'x' => srwx |= 0o111,
            'X' => {
                if considering_dir || (fperm & 0o0111) != 0 {
                    srwx |= 0o111;
                }
            }
            's' => srwx |= 0o4000 | 0o2000,
            't' => srwx |= 0o1000,
            'u' => srwx = (fperm & 0o700) | ((fperm >> 3) & 0o070) | ((fperm >> 6) & 0o007),
            'g' => srwx = ((fperm << 3) & 0o700) | (fperm & 0o070) | ((fperm >> 3) & 0o007),
            'o' => srwx = ((fperm << 6) & 0o700) | ((fperm << 3) & 0o070) | (fperm & 0o007),
            _ => break,
        }
        if ch == 'u' || ch == 'g' || ch == 'o' {
            // symbolic modes only allows perms to be a single letter of 'ugo'
            // therefore this must either be the first char or it is unexpected
            if pos != 0 {
                break;
            }
            pos = 1;
            break;
        }
        pos += 1;
    }
    if pos == 0 {
        srwx = 0;
    }
    (srwx, pos)
}

// Parse a mode string, which may be numeric (e.g., "755") or symbolic (e.g., "u+rwx").
// Supports multiple comma-separated mode parts (e.g., "u+rwx,g+rx,o+r").
//
// The mode is applied to the given current_mode.
//
// If mode is None, the resulting mode is current_mode masked by the inverse of umask.
// If umask is None, the system's current umask is used.
pub fn parse(
    current_mode: u32,
    mode: Option<&str>,
    considering_dir: bool,
    umask: Option<u32>,
) -> Result<u32, String> {
    match mode {
        Some(mode_string) => {
            let mut new_mode: u32 = current_mode;
            for mode_part in mode_string.split(',') {
                let mode_part = mode_part.trim();
                if mode_part.is_empty() {
                    continue;
                }

                new_mode = if mode_part.chars().any(|c| c.is_ascii_digit()) {
                    parse_numeric(new_mode, mode_part, considering_dir)?
                } else {
                    parse_symbolic(
                        new_mode,
                        mode_part,
                        umask.unwrap_or(get_umask()),
                        considering_dir,
                    )?
                };
            }

            Ok(new_mode)
        }
        None => Ok(!umask.unwrap_or(get_umask()) & current_mode),
    }
}

pub fn get_umask() -> u32 {
    // There's no portable way to read the umask without changing it.
    // We have to replace it and then quickly set it back, hopefully before
    // some other thread is affected.
    // On modern Linux kernels the current umask could instead be read
    // from /proc/self/status. But that's a lot of work.
    // SAFETY: umask always succeeds and doesn't operate on memory. Races are
    // possible but it can't violate Rust's guarantees.
    let mask = unsafe { umask(0) };
    unsafe { umask(mask) };
    #[cfg(all(
        not(target_os = "freebsd"),
        not(target_vendor = "apple"),
        not(target_os = "android"),
        not(target_os = "redox")
    ))]
    return mask;
    #[cfg(any(
        target_os = "freebsd",
        target_vendor = "apple",
        target_os = "android",
        target_os = "redox"
    ))]
    return mask as u32;
}

// #[cfg(not(windows))]

#[cfg(test)]
mod test {
    use super::parse;

    #[test]
    fn symbolic_modes() {
        assert_eq!(parse(0, Some("u+x"), true, Some(0)).unwrap(), 0o766);
        assert_eq!(
            parse(0, Some("+x"), true, Some(0)).unwrap(),
            if crate::os::is_wsl_1() { 0o776 } else { 0o777 }
        );
        assert_eq!(parse(0, Some("a-w"), true, Some(0)).unwrap(), 0o444);
        assert_eq!(parse(0, Some("g-r"), true, Some(0)).unwrap(), 0o626);
    }

    #[test]
    fn numeric_modes() {
        assert_eq!(parse(0, Some("644"), true, Some(0)).unwrap(), 0o644);
        assert_eq!(parse(0, Some("+100"), true, Some(0)).unwrap(), 0o766);
        assert_eq!(parse(0, Some("-4"), true, Some(0)).unwrap(), 0o662);
    }

    #[test]
    fn test_parse_numeric_mode() {
        // Simple numeric mode
        assert_eq!(parse(0, Some("644"), false, Some(0)).unwrap(), 0o644);
        assert_eq!(parse(0, Some("755"), false, Some(0)).unwrap(), 0o755);
        assert_eq!(parse(0, Some("777"), false, Some(0)).unwrap(), 0o777);
        assert_eq!(parse(0, Some("600"), false, Some(0)).unwrap(), 0o600);
    }

    #[test]
    fn test_parse_numeric_mode_with_operator() {
        // Numeric mode with + operator
        assert_eq!(parse(0, Some("+100"), false, Some(0)).unwrap(), 0o100);
        assert_eq!(parse(0, Some("+644"), false, Some(0)).unwrap(), 0o644);

        // Numeric mode with - operator (starting from 0, so nothing to remove)
        assert_eq!(parse(0, Some("-4"), false, Some(0)).unwrap(), 0);
        // But if we first set a mode, then remove bits
        assert_eq!(parse(0, Some("644,-4"), false, Some(0)).unwrap(), 0o640);
    }

    #[test]
    fn test_parse_symbolic_mode() {
        // Simple symbolic modes
        assert_eq!(parse(0, Some("u+x"), false, Some(0)).unwrap(), 0o100);
        assert_eq!(parse(0, Some("g+w"), false, Some(0)).unwrap(), 0o020);
        assert_eq!(parse(0, Some("o+r"), false, Some(0)).unwrap(), 0o004);
        assert_eq!(parse(0, Some("a+x"), false, Some(0)).unwrap(), 0o111);
    }

    #[test]
    fn test_parse_symbolic_mode_multiple_permissions() {
        // Multiple permissions in one mode
        assert_eq!(parse(0, Some("u+rw"), false, Some(0)).unwrap(), 0o600);
        assert_eq!(parse(0, Some("ug+rwx"), false, Some(0)).unwrap(), 0o770);
        assert_eq!(parse(0, Some("a+rwx"), false, Some(0)).unwrap(), 0o777);
    }

    #[test]
    fn test_parse_comma_separated_modes() {
        // Comma-separated mode strings (as mentioned in the doc comment)
        assert_eq!(
            parse(0, Some("ug+rwX,o+rX"), false, Some(0)).unwrap(),
            0o664
        );
        assert_eq!(
            parse(0, Some("u+rwx,g+rx,o+r"), false, Some(0)).unwrap(),
            0o754
        );
        assert_eq!(
            parse(0, Some("u+w,g+w,o+w"), false, Some(0)).unwrap(),
            0o222
        );
    }

    #[test]
    fn test_parse_comma_separated_with_spaces() {
        // Comma-separated with spaces (should be trimmed)
        assert_eq!(
            parse(0, Some("u+rw, g+rw, o+r"), false, Some(0)).unwrap(),
            0o664
        );
        assert_eq!(
            parse(0, Some(" u+x , g+x "), false, Some(0)).unwrap(),
            0o110
        );
    }

    #[test]
    fn test_parse_mixed_numeric_and_symbolic() {
        // Mix of numeric and symbolic modes
        assert_eq!(parse(0, Some("644,u+x"), false, Some(0)).unwrap(), 0o744);
        assert_eq!(parse(0, Some("u+rw,755"), false, Some(0)).unwrap(), 0o755);
    }

    #[test]
    fn test_parse_empty_string() {
        // Empty string should return 0
        assert_eq!(parse(0, Some(""), false, Some(0)).unwrap(), 0);
        assert_eq!(parse(0, Some("   "), false, Some(0)).unwrap(), 0);
        assert_eq!(parse(0, Some(",,"), false, Some(0)).unwrap(), 0);
    }

    #[test]
    fn test_parse_with_umask() {
        // Test with umask (affects symbolic modes when no level is specified)
        let umask = 0o022;
        assert_eq!(parse(0, Some("+w"), false, Some(umask)).unwrap(), 0o200);
        // The umask should be respected for symbolic modes without explicit level
    }

    #[test]
    fn test_parse_considering_dir() {
        // Test directory vs file mode differences
        // For directories, X (capital X) should add execute permission
        assert_eq!(parse(0, Some("a+X"), true, Some(0)).unwrap(), 0o111);
        // For files without execute, X should not add execute
        assert_eq!(parse(0, Some("a+X"), false, Some(0)).unwrap(), 0o000);

        // Numeric modes for directories preserve setuid/setgid bits
        assert_eq!(parse(0, Some("755"), true, Some(0)).unwrap(), 0o755);
    }

    #[test]
    fn test_parse_invalid_modes() {
        // Invalid numeric mode (too large)
        assert!(parse(0, Some("10000"), false, Some(0)).is_err());

        // Invalid operator
        assert!(parse(0, Some("u*rw"), false, Some(0)).is_err());

        // Invalid symbolic mode
        assert!(parse(0, Some("invalid"), false, Some(0)).is_err());
    }

    #[test]
    fn test_parse_complex_combinations() {
        // Complex real-world examples
        assert_eq!(
            parse(0, Some("u=rwx,g=rx,o=r"), false, Some(0)).unwrap(),
            0o754
        );
        // To test removal, we need to first set permissions, then remove them
        assert_eq!(parse(0, Some("644,a-w"), false, Some(0)).unwrap(), 0o444);
        assert_eq!(parse(0, Some("644,g-r"), false, Some(0)).unwrap(), 0o604);
    }

    #[test]
    fn test_parse_sequential_application() {
        // Test that comma-separated modes are applied sequentially
        // First set to 644, then add execute for user
        assert_eq!(parse(0, Some("644,u+x"), false, Some(0)).unwrap(), 0o744);

        // First add user write, then set to 755 (should override)
        assert_eq!(parse(0, Some("u+w,755"), false, Some(0)).unwrap(), 0o755);
    }
}

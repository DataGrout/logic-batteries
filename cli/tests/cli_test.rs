//! End-to-end tests for the `battery` CLI, run against the real repo's
//! modules/ tree (the crate lives inside the logic-batteries checkout).

use std::fs;
use std::path::{Path, PathBuf};
use std::process::{Command, Output};
use std::sync::atomic::{AtomicU32, Ordering};

static COUNTER: AtomicU32 = AtomicU32::new(0);

fn repo_root() -> PathBuf {
    // cli/ lives at the repo root.
    Path::new(env!("CARGO_MANIFEST_DIR")).parent().unwrap().to_path_buf()
}

fn temp_dir() -> PathBuf {
    let n = COUNTER.fetch_add(1, Ordering::SeqCst);
    let dir = std::env::temp_dir().join(format!(
        "battery-cli-test-{}-{n}",
        std::process::id()
    ));
    fs::create_dir_all(&dir).unwrap();
    dir
}

fn battery(args: &[&str]) -> Output {
    Command::new(env!("CARGO_BIN_EXE_battery"))
        .args(args)
        .output()
        .expect("failed to run battery binary")
}

fn stdout(o: &Output) -> String {
    String::from_utf8_lossy(&o.stdout).to_string()
}

fn stderr(o: &Output) -> String {
    String::from_utf8_lossy(&o.stderr).to_string()
}

#[test]
fn list_shows_registry_batteries() {
    let repo = repo_root();
    let out = battery(&["list", "--repo", repo.to_str().unwrap()]);
    assert!(out.status.success(), "{}", stderr(&out));
    let text = stdout(&out);
    assert!(text.contains("prob-core-iso"), "list missing prob-core-iso:\n{text}");
    assert!(text.contains("explain"), "list missing explain:\n{text}");
}

#[test]
fn install_copies_files_and_writes_lock() {
    let repo = repo_root();
    let dir = temp_dir();

    let out = battery(&[
        "install", "explain",
        "--repo", repo.to_str().unwrap(),
        "--dir", dir.to_str().unwrap(),
    ]);
    assert!(out.status.success(), "{}", stderr(&out));
    assert!(dir.join("explain.pl").is_file());

    let lock: serde_json::Value =
        serde_json::from_str(&fs::read_to_string(dir.join("batteries.lock.json")).unwrap()).unwrap();
    let files = lock["batteries"]["explain"]["files"].as_object().unwrap();
    assert!(files.contains_key("explain.pl"));
    assert_eq!(files["explain.pl"].as_str().unwrap().len(), 64); // sha256 hex

    // Idempotent: second install reports already installed.
    let again = battery(&[
        "install", "explain",
        "--repo", repo.to_str().unwrap(),
        "--dir", dir.to_str().unwrap(),
    ]);
    assert!(stdout(&again).contains("already installed"));
}

#[test]
fn install_hints_missing_requires() {
    let repo = repo_root();
    let dir = temp_dir();

    // prob-decide requires prob-core-iso.
    let out = battery(&[
        "install", "prob-decide",
        "--repo", repo.to_str().unwrap(),
        "--dir", dir.to_str().unwrap(),
    ]);
    assert!(out.status.success(), "{}", stderr(&out));
    assert!(
        stdout(&out).contains("requires prob-core-iso"),
        "no dependency hint:\n{}",
        stdout(&out)
    );

    // Installing both together produces no hint.
    let dir2 = temp_dir();
    let both = battery(&[
        "install", "prob-core-iso", "prob-decide",
        "--repo", repo.to_str().unwrap(),
        "--dir", dir2.to_str().unwrap(),
    ]);
    assert!(!stdout(&both).contains("hint:"), "unexpected hint:\n{}", stdout(&both));
}

#[test]
fn remove_deletes_only_checksummed_files() {
    let repo = repo_root();
    let dir = temp_dir();

    battery(&[
        "install", "explain",
        "--repo", repo.to_str().unwrap(),
        "--dir", dir.to_str().unwrap(),
    ]);

    let out = battery(&["remove", "explain", "--dir", dir.to_str().unwrap()]);
    assert!(out.status.success(), "{}", stderr(&out));
    assert!(!dir.join("explain.pl").exists());
    assert!(!dir.join("batteries.lock.json").exists(), "empty lock should be cleaned up");
}

#[test]
fn remove_keeps_modified_files_without_force() {
    let repo = repo_root();
    let dir = temp_dir();

    battery(&[
        "install", "explain",
        "--repo", repo.to_str().unwrap(),
        "--dir", dir.to_str().unwrap(),
    ]);

    // User edits the installed battery.
    let target = dir.join("explain.pl");
    let mut content = fs::read_to_string(&target).unwrap();
    content.push_str("\n% user tweak\n");
    fs::write(&target, content).unwrap();

    let out = battery(&["remove", "explain", "--dir", dir.to_str().unwrap()]);
    assert!(out.status.success());
    assert!(target.is_file(), "modified file must be kept");
    assert!(stdout(&out).contains("modified"), "{}", stdout(&out));

    // -f deletes it.
    let forced = battery(&["remove", "explain", "--dir", dir.to_str().unwrap(), "-f"]);
    assert!(forced.status.success(), "{}", stderr(&forced));
    assert!(!target.exists());
}

#[test]
fn install_refuses_to_clobber_foreign_files_without_force() {
    let repo = repo_root();
    let dir = temp_dir();

    // A pre-existing, unrelated explain.pl the user wrote themselves.
    fs::write(dir.join("explain.pl"), "% my own file\n").unwrap();

    let out = battery(&[
        "install", "explain",
        "--repo", repo.to_str().unwrap(),
        "--dir", dir.to_str().unwrap(),
    ]);
    assert!(!out.status.success(), "should refuse to overwrite");
    assert!(stderr(&out).contains("-f"), "{}", stderr(&out));
    assert_eq!(fs::read_to_string(dir.join("explain.pl")).unwrap(), "% my own file\n");

    let forced = battery(&[
        "install", "explain",
        "--repo", repo.to_str().unwrap(),
        "--dir", dir.to_str().unwrap(),
        "-f",
    ]);
    assert!(forced.status.success(), "{}", stderr(&forced));
    assert_ne!(fs::read_to_string(dir.join("explain.pl")).unwrap(), "% my own file\n");
}

#[test]
fn installed_reports_state_and_modifications() {
    let repo = repo_root();
    let dir = temp_dir();

    battery(&[
        "install", "prob-core-iso",
        "--repo", repo.to_str().unwrap(),
        "--dir", dir.to_str().unwrap(),
    ]);

    let out = battery(&["installed", "--dir", dir.to_str().unwrap()]);
    assert!(stdout(&out).contains("prob-core-iso"));
    assert!(!stdout(&out).contains("(modified)"));

    // Modify one installed file → flagged.
    let target = dir.join("prob_core_iso.pl");
    fs::write(&target, "% clobbered\n").unwrap();
    let after = battery(&["installed", "--dir", dir.to_str().unwrap()]);
    assert!(stdout(&after).contains("(modified)"), "{}", stdout(&after));
}

#[test]
fn unknown_battery_is_a_clean_error() {
    let repo = repo_root();
    let dir = temp_dir();

    let out = battery(&[
        "install", "no-such-battery",
        "--repo", repo.to_str().unwrap(),
        "--dir", dir.to_str().unwrap(),
    ]);
    assert!(!out.status.success());
    assert!(stderr(&out).contains("unknown battery"));
}

//! `battery` — install Logic Batteries into any Prolog project.
//!
//! Batteries are plain ISO/SWI Prolog files; this CLI copies a battery's
//! rule files from a logic-batteries repo checkout into a target directory
//! (default: cwd) so a bare `swipl`/`scryer-prolog` app can consult them.
//! No DataGrout account or server involved.
//!
//! Every installed file is content-hashed into `batteries.lock.json` in the
//! target directory. `remove` only deletes files whose current hash still
//! matches what we installed — a user-modified battery is warned about and
//! kept unless `-f`. Command shapes mirror the DataGrout MCP batteries suite
//! (install/remove/installed/list with battery ids).

use sha2::{Digest, Sha256};
use std::collections::BTreeMap;
use std::fs;
use std::path::{Path, PathBuf};
use std::process::exit;

const LOCK_FILE: &str = "batteries.lock.json";

fn main() {
    let args: Vec<String> = std::env::args().skip(1).collect();
    let (cmd, rest) = match args.split_first() {
        Some((c, r)) => (c.as_str(), r.to_vec()),
        None => {
            usage();
            exit(2);
        }
    };

    let result = match cmd {
        "install" => cmd_install(&rest),
        "remove" => cmd_remove(&rest),
        "installed" => cmd_installed(&rest),
        "list" => cmd_list(&rest),
        "help" | "--help" | "-h" => {
            usage();
            Ok(())
        }
        other => Err(format!("unknown command '{other}' — try `battery help`")),
    };

    if let Err(e) = result {
        eprintln!("error: {e}");
        exit(1);
    }
}

fn usage() {
    println!(
        "battery — install Logic Batteries into any Prolog project

USAGE:
  battery install <id>... [--dir DIR] [--repo REPO] [-f]
  battery remove  <id>... [--dir DIR] [-f]
  battery installed       [--dir DIR]
  battery list            [--repo REPO]

  --dir DIR    target project directory (default: current directory)
  --repo REPO  logic-batteries checkout (default: $LB_REPO, else walk up from cwd)
  -f           force: overwrite differing files on install / delete modified files on remove

Installed files are content-hashed into {}; `remove` refuses to delete
files you have modified unless -f.",
        LOCK_FILE
    );
}

// ── arg parsing ─────────────────────────────────────────────────────────────

struct Opts {
    ids: Vec<String>,
    dir: PathBuf,
    repo: Option<PathBuf>,
    force: bool,
}

fn parse_opts(args: &[String]) -> Result<Opts, String> {
    let mut ids = Vec::new();
    let mut dir = std::env::current_dir().map_err(|e| e.to_string())?;
    let mut repo = None;
    let mut force = false;

    let mut i = 0;
    while i < args.len() {
        match args[i].as_str() {
            "--dir" => {
                i += 1;
                dir = PathBuf::from(args.get(i).ok_or("--dir needs a value")?);
            }
            "--repo" => {
                i += 1;
                repo = Some(PathBuf::from(args.get(i).ok_or("--repo needs a value")?));
            }
            "-f" | "--force" => force = true,
            flag if flag.starts_with('-') => return Err(format!("unknown flag '{flag}'")),
            id => ids.push(id.to_string()),
        }
        i += 1;
    }

    Ok(Opts { ids, dir, repo, force })
}

// ── repo discovery ──────────────────────────────────────────────────────────

/// Locate a logic-batteries checkout: explicit --repo, then $LB_REPO, then
/// walking up from cwd looking for a `modules/` directory with registries.
fn find_repo(explicit: &Option<PathBuf>) -> Result<PathBuf, String> {
    if let Some(p) = explicit {
        return check_repo(p).ok_or_else(|| format!("{} is not a logic-batteries checkout", p.display()));
    }

    if let Ok(env) = std::env::var("LB_REPO") {
        let p = PathBuf::from(env);
        return check_repo(&p)
            .ok_or_else(|| format!("$LB_REPO ({}) is not a logic-batteries checkout", p.display()));
    }

    let mut cur = std::env::current_dir().map_err(|e| e.to_string())?;
    loop {
        if let Some(found) = check_repo(&cur) {
            return Ok(found);
        }
        if !cur.pop() {
            return Err(
                "no logic-batteries checkout found — pass --repo or set $LB_REPO".to_string(),
            );
        }
    }
}

fn check_repo(p: &Path) -> Option<PathBuf> {
    let modules = p.join("modules");
    if modules.is_dir()
        && fs::read_dir(&modules)
            .ok()?
            .flatten()
            .any(|cat| cat.path().join("registry.json").is_file())
    {
        Some(p.to_path_buf())
    } else {
        None
    }
}

// ── registry ────────────────────────────────────────────────────────────────

struct Battery {
    id: String,
    version: String,
    title: String,
    dir: PathBuf,
    requires: Vec<String>,
}

fn load_registry(repo: &Path) -> Result<Vec<Battery>, String> {
    let mut out = Vec::new();
    let modules = repo.join("modules");

    for cat in fs::read_dir(&modules).map_err(|e| e.to_string())?.flatten() {
        let reg_path = cat.path().join("registry.json");
        if !reg_path.is_file() {
            continue;
        }

        let raw = fs::read_to_string(&reg_path).map_err(|e| e.to_string())?;
        let json: serde_json::Value =
            serde_json::from_str(&raw).map_err(|e| format!("{}: {e}", reg_path.display()))?;

        for m in json["modules"].as_array().into_iter().flatten() {
            let id = m["id"].as_str().unwrap_or_default().to_string();
            let dir = cat.path().join(&id);
            if id.is_empty() || !dir.is_dir() {
                continue;
            }

            out.push(Battery {
                requires: requires_of(&dir),
                id,
                version: m["version"].as_str().unwrap_or("0.0.0").to_string(),
                title: m["title"].as_str().unwrap_or_default().to_string(),
                dir,
            });
        }
    }

    out.sort_by(|a, b| a.id.cmp(&b.id));
    Ok(out)
}

/// Parse the `%% Requires: a, b` manifest header from the battery's .pl files.
fn requires_of(dir: &Path) -> Vec<String> {
    for file in pl_files(dir) {
        if let Ok(text) = fs::read_to_string(&file) {
            for line in text.lines().take(10) {
                if let Some(rest) = line.trim().strip_prefix("%% Requires:") {
                    return rest
                        .split(',')
                        .map(|s| s.trim().trim_end_matches('.').to_string())
                        .filter(|s| !s.is_empty() && s != "(nothing)")
                        .collect();
                }
            }
        }
    }
    Vec::new()
}

fn pl_files(dir: &Path) -> Vec<PathBuf> {
    let mut files: Vec<PathBuf> = fs::read_dir(dir)
        .into_iter()
        .flatten()
        .flatten()
        .map(|e| e.path())
        .filter(|p| p.extension().map(|x| x == "pl").unwrap_or(false))
        .collect();
    files.sort();
    files
}

// ── lock file ───────────────────────────────────────────────────────────────

type Lock = BTreeMap<String, LockEntry>;

struct LockEntry {
    version: String,
    files: BTreeMap<String, String>, // filename → sha256
}

fn read_lock(dir: &Path) -> Result<Lock, String> {
    let path = dir.join(LOCK_FILE);
    if !path.is_file() {
        return Ok(Lock::new());
    }

    let raw = fs::read_to_string(&path).map_err(|e| e.to_string())?;
    let json: serde_json::Value = serde_json::from_str(&raw).map_err(|e| e.to_string())?;
    let mut lock = Lock::new();

    for (id, entry) in json["batteries"].as_object().into_iter().flatten() {
        let files = entry["files"]
            .as_object()
            .into_iter()
            .flatten()
            .filter_map(|(k, v)| v.as_str().map(|s| (k.clone(), s.to_string())))
            .collect();

        lock.insert(
            id.clone(),
            LockEntry {
                version: entry["version"].as_str().unwrap_or("0.0.0").to_string(),
                files,
            },
        );
    }

    Ok(lock)
}

fn write_lock(dir: &Path, lock: &Lock) -> Result<(), String> {
    let batteries: serde_json::Map<String, serde_json::Value> = lock
        .iter()
        .map(|(id, e)| {
            (
                id.clone(),
                serde_json::json!({
                    "version": e.version,
                    "files": e.files,
                }),
            )
        })
        .collect();

    let doc = serde_json::json!({ "version": 1, "batteries": batteries });
    let path = dir.join(LOCK_FILE);

    if lock.is_empty() {
        // Last battery removed — clean up rather than leaving an empty lock.
        let _ = fs::remove_file(&path);
        return Ok(());
    }

    fs::write(&path, serde_json::to_string_pretty(&doc).unwrap() + "\n").map_err(|e| e.to_string())
}

fn sha256_file(path: &Path) -> Result<String, String> {
    let bytes = fs::read(path).map_err(|e| format!("{}: {e}", path.display()))?;
    Ok(format!("{:x}", Sha256::digest(&bytes)))
}

// ── commands ────────────────────────────────────────────────────────────────

fn cmd_install(args: &[String]) -> Result<(), String> {
    let opts = parse_opts(args)?;
    if opts.ids.is_empty() {
        return Err("install needs at least one battery id".to_string());
    }

    let repo = find_repo(&opts.repo)?;
    let registry = load_registry(&repo)?;
    fs::create_dir_all(&opts.dir).map_err(|e| e.to_string())?;
    let mut lock = read_lock(&opts.dir)?;

    for id in &opts.ids {
        let bat = registry
            .iter()
            .find(|b| &b.id == id)
            .ok_or_else(|| format!("unknown battery '{id}' — see `battery list`"))?;

        if let Some(entry) = lock.get(id) {
            if entry.version == bat.version && files_match(&opts.dir, entry) {
                println!("• {id} {} already installed", bat.version);
                continue;
            }
        }

        let mut hashes = BTreeMap::new();
        for src in pl_files(&bat.dir) {
            let name = src.file_name().unwrap().to_string_lossy().to_string();
            let dest = opts.dir.join(&name);

            if dest.exists() && !opts.force {
                let src_hash = sha256_file(&src)?;
                let dest_hash = sha256_file(&dest)?;
                let owned_by_us = lock.get(id).map(|e| e.files.contains_key(&name)).unwrap_or(false);

                if src_hash != dest_hash && !owned_by_us {
                    return Err(format!(
                        "{} already exists in {} with different content — re-run with -f to overwrite",
                        name,
                        opts.dir.display()
                    ));
                }
            }

            fs::copy(&src, &dest).map_err(|e| format!("copy {name}: {e}"))?;
            hashes.insert(name, sha256_file(&dest)?);
        }

        let missing_deps: Vec<&String> = bat
            .requires
            .iter()
            .filter(|dep| !lock.contains_key(*dep) && !opts.ids.contains(dep))
            .collect();

        println!(
            "✓ installed {id} {} ({} file{})",
            bat.version,
            hashes.len(),
            if hashes.len() == 1 { "" } else { "s" }
        );

        if !missing_deps.is_empty() {
            println!(
                "  hint: {id} requires {} — install with `battery install {}`",
                missing_deps.iter().map(|s| s.as_str()).collect::<Vec<_>>().join(", "),
                missing_deps.iter().map(|s| s.as_str()).collect::<Vec<_>>().join(" ")
            );
        }

        lock.insert(id.clone(), LockEntry { version: bat.version.clone(), files: hashes });
    }

    write_lock(&opts.dir, &lock)
}

fn files_match(dir: &Path, entry: &LockEntry) -> bool {
    entry.files.iter().all(|(name, hash)| {
        let p = dir.join(name);
        p.is_file() && sha256_file(&p).map(|h| &h == hash).unwrap_or(false)
    })
}

fn cmd_remove(args: &[String]) -> Result<(), String> {
    let opts = parse_opts(args)?;
    if opts.ids.is_empty() {
        return Err("remove needs at least one battery id".to_string());
    }

    let mut lock = read_lock(&opts.dir)?;

    for id in &opts.ids {
        let entry = match lock.get(id) {
            Some(e) => e,
            None => {
                println!("• {id} is not installed in {}", opts.dir.display());
                continue;
            }
        };

        let mut kept = Vec::new();
        for (name, recorded_hash) in &entry.files {
            let path = opts.dir.join(name);

            if !path.is_file() {
                println!("• {name} already gone");
                continue;
            }

            let current = sha256_file(&path)?;
            if &current == recorded_hash || opts.force {
                fs::remove_file(&path).map_err(|e| format!("remove {name}: {e}"))?;
                if &current != recorded_hash {
                    println!("! deleted MODIFIED {name} (forced)");
                } else {
                    println!("✓ removed {name}");
                }
            } else {
                println!("! {name} was modified since install — keeping it (re-run with -f to delete)");
                kept.push(name.clone());
            }
        }

        if kept.is_empty() {
            lock.remove(id);
            println!("✓ removed {id}");
        } else {
            println!("• {id} partially removed — {} modified file(s) kept", kept.len());
        }
    }

    write_lock(&opts.dir, &lock)
}

fn cmd_installed(args: &[String]) -> Result<(), String> {
    let opts = parse_opts(args)?;
    let lock = read_lock(&opts.dir)?;

    if lock.is_empty() {
        println!("no batteries installed in {}", opts.dir.display());
        return Ok(());
    }

    for (id, entry) in &lock {
        let status = if files_match(&opts.dir, entry) { "" } else { "  (modified)" };
        println!("{id} {}{status}", entry.version);
    }

    Ok(())
}

fn cmd_list(args: &[String]) -> Result<(), String> {
    let opts = parse_opts(args)?;
    let repo = find_repo(&opts.repo)?;

    for bat in load_registry(&repo)? {
        println!("{:<18} {:<8} {}", bat.id, bat.version, bat.title);
    }

    Ok(())
}

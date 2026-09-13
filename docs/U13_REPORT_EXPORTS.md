# One upload file per run

`run_u13_doctrine.sh`, `run_u13_resolution_perf.sh`, and
`run_u13_full_matches.sh` now finish by creating one uniquely named ZIP directly
in Downloads. The filename includes the report-folder name, date/time, and a
unique suffix. The final `UPLOAD THIS FILE:` line gives the exact path; Git Bash
also prints the Windows path for File Explorer.

The ZIP contains that run's logs, JSON reports, checkpoints, and `run-status.txt`
with runner/revision/exit status. Match subfolders remain inside the ZIP, so the
entire run can be uploaded without locating individual files. Original report
folders are retained. Repeated exports create new ZIPs without replacing earlier
ones.

Failed, capped, and normally interrupted runs also attempt an export, after the
runner has stopped and waited for its workers. Compression errors are reported
without changing the test exit status or deleting the original reports. Forced
process termination or power loss cannot execute the exit handler; the retained
folder can be packaged afterward.

All three runners now use a fresh default report folder for every invocation.
The full-match runner's optional second argument still selects an existing folder
for its existing resume behavior, subject to matching run configuration.

To package an already completed run without running Godot again:

```bash
bash Scripts/Sim/package_u13_reports.sh \
  "$HOME/Downloads/u13-doctrine-217565b0-c5TMc2"
```

The helper accepts an optional destination directory as argument 2. Alternatively,
`U13_REPORT_DOWNLOADS` changes the ZIP destination for automated runners. The
default remains `$HOME/Downloads`. The destination must be outside the source
folder to prevent including the archive in itself.

Windows Git Bash uses built-in PowerShell/.NET ZIP support and passes paths as
environment data, so no Python or zip installation is required. Other systems
use `zip`, with `python3` as a fallback. Filenames and contents are preserved.

Local scheduler/export tests use a fake engine (not gameplay acceptance):
`python3 Scripts/Sim/test_u13_report_exports.py`. They verify success/failure/cap
exit status, archive contents, worker cleanup on interruption, export-error
handling, and repeated exports of paths containing spaces and special characters.

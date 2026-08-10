Random, assorted fixes for small annoyances in Chrultrabooks running Windows. Some are device-specific.

`patch_lock_to_delete.py` converts the Lock key (above Backspace) onto a more useful (and less workflow-intrusive) Delete key. Tested on Redrix and Pantheon
`keyboard speed filter fix.reg` fixes the wrong keyboard repeat speed (very slow after waking up from sleep) -- Tested on Panthen, unnecessary on Redrix
`scrap_dptf_drivers.ps1` gets rid of DPTF drivers with cause issues in Pantheon, limiting performance on battery to ~9W

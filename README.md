Random, assorted fixes for small annoyances in specific Chrultrabooks running Windows. Some are device-specific.

 - `patch_lock_to_delete.py` converts the Lock key (above Backspace) onto a more useful (and less workflow-intrusive) Delete key. Tested on Redrix and Pantheon;
 - `keyboard speed filter fix.reg` fixes the wrong keyboard repeat speed (very slow after waking up from sleep) -- Tested on Panthen, unnecessary on Redrix;
 - `scrap_dptf_drivers.ps1` gets rid of DPTF drivers (which cause issues in Pantheon, limiting performance on battery to ~9W);

Future improvements (To Do):
 - Set RGB/BGR ClearType mode automatically on screen rotate
 - Fork/update [RightKeyboard](https://github.com/mnivet/RightKeyboard) to make it remember disconnected Bluetooth keyboards/mice to avoid them asking layout again every time (not really a specific Chrultrabook bug though -- just noted here as it's relevant for my Redrix with US keyboard in an otherwise ABNT2 region).
 - ...
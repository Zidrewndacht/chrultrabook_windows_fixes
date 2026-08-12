Assorted selection fixes for small annoyances in specific Chrultrabooks running Windows. Some are device-specific. They're being built and added according to my own usage and are mostly *"educated vibecoded"* scripts at different levels of (lack of) polish, below what I'd do for a "proper" published app. So usability and performance may not be the best, but they should still do their job.

General purpose for most Chrultrabook convertible tablets:
 - `patch_lock_to_delete.py` converts the Lock key (above Backspace) onto a more useful (and less workflow-intrusive) Delete key. Tested on Redrix and Pantheon. Leverages croskbsettings from [Coolstar drivers](https://github.com/coolstar/croskeyboard4);
 - `install-cleartype-BGR-fix` (which creates a scheduled task for `cleartype.ps1` that has to be in a place it won't be deleted from): automatically changes display to BGR mode when rotated. This also auto-disables the Precision Touchpad on slate mode. Seems to work fine, but it's a C# application compiled from PowerShell and takes ~27MB of RAM, a bit on the fat side for the functionality. As Redrix has 32GB LP4x, won't bother improving that at this time.

Specific for Pantheon/Nami:
 - `keyboard speed filter fix.reg` fixes the wrong keyboard repeat speed (very slow after waking up from sleep) -- Tested on Panthen, unnecessary on Redrix;
 - `scrap_dptf_drivers.ps1` gets rid of DPTF drivers (which cause issues in Pantheon, limiting performance on battery to ~9W) -- NOT for Redrix;


Future improvements (To Do):

 - Fork/update [RightKeyboard](https://github.com/mnivet/RightKeyboard) to make it remember disconnected Bluetooth keyboards/mice to avoid them asking layout again every time (not really a specific Chrultrabook bug though -- just noted here as it's relevant for my Redrix with US keyboard in an otherwise ABNT2 region).
 - ...?
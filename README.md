# ZeroTier Setup for Steam Deck

If you’ve been fighting to get ZeroTier working on your Steam Deck, this script should make your life easier.  
It fixes the usual SteamOS problems — the read-only filesystem, broken pacman keys, failed installs — and sets up ZeroTier so it actually stays online, even in Game Mode.  

---

## How to Use

1. Switch your Steam Deck to **Desktop Mode** and open **Konsole**.

2. Save or copy the script (`zerotier_setup.sh`) somewhere, for example:
   ```bash
   cd ~/Downloads

3. Make it executable:
	```bash

	chmod +x zerotier_setup.sh


4. Run it:
	```bash

	./zerotier_setup.sh

You can also control how much it talks:

Quiet mode (just the essentials):
  
	./zerotier_setup.sh quiet

Verbose mode (shows every command it runs):
  
	./zerotier_setup.sh verbose


5. When it asks for your ZeroTier Network ID, paste the one from my.zerotier.com.


6. Let it finish.
Once it’s done, ZeroTier will stay connected automatically — even after restarts or when you switch to Game Mode.




---

Check if It’s Working

See if ZeroTier is online:

	sudo zerotier-cli info

You should get something like:

	200 info <node_id> 1.x.x ONLINE

To check the small watchdog service that keeps it running:

	systemctl status zerotier-watchdog.service

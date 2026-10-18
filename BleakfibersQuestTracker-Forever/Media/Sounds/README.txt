Bleakfiber's Quest Tracker - Custom Sounds Guide
==================================================

How to Add Your Own Custom Sounds:
----------------------------------
1. Copy your .wav audio file into this folder:
   World of Warcraft\Interface\AddOns\BleakfibersQuestTracker-Forever\Media\Sounds\

2. Name your file whatever you like (e.g. fart.wav, cheer.wav, levelup.wav, custom1.wav).

   Bundled presets already included in this folder:
   - beep.wav   (Clean subtle tone)
   - click.wav  (Soft tick)

3. Restart World of Warcraft:
   IMPORTANT: If you add a new audio file while WoW is running, you must COMPLETELY RESTART the WoW client.
   The World of Warcraft engine only indexes new files on disk during initial game launch; typing /reload will not discover new files.

4. Register your sound in the tracker (choose either Method A or Method B):

   Method A - Directly In-Game (Recommended):
   - Type /bqt to open settings and select "Audio".
   - Scroll to "Custom Audio Files".
   - Type your filename (e.g. fart.wav) into the text box and click "Add Sound".
   - Your sound will immediately appear in the "Quest Complete Sound" and "Objective Progress Sound" dropdowns as:
     Custom 1 (fart.wav), Custom 2 (cheer.wav), etc.
   - Only your registered custom sounds are shown in the dropdown (no 1-99 clutter!).

   Method B - Text File Editing:
   - Open Media\CustomSounds.lua in any text editor.
   - Add your filename to the list:
     BleakfiberCustomSounds = {
         "fart.wav",
         "cheer.wav",
     }
   - Launch WoW. Your custom sounds will automatically appear in the sound dropdowns as:
     Custom 1 (fart.wav), Custom 2 (cheer.wav), etc.

Supported Audio Format:
- Standard 16-bit 44.1kHz (or 22.05kHz) PCM .wav (Stereo or Mono).

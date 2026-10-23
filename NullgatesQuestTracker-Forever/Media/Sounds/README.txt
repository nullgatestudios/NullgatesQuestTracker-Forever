Nullgate's Quest Tracker - Custom Sounds Guide
==================================================

How to Add Your Own Custom Sounds:
----------------------------------
1. Copy your .ogg or .mp3 audio file into this folder:
   World of Warcraft\Interface\AddOns\NullgatesQuestTracker-Forever\Media\Sounds\

2. Name your file whatever you like (e.g. fart.ogg, cheer.ogg, levelup.mp3, custom1.ogg).

   Bundled presets already included in this folder:
   - beep.ogg   (Clean subtle tone)
   - click.ogg  (Soft tick)

3. Restart World of Warcraft:
   IMPORTANT: If you add a new audio file while WoW is running, you must COMPLETELY RESTART the WoW client.
   The World of Warcraft engine only indexes new files on disk during initial game launch; typing /reload will not discover new files.

4. Register your sound in the tracker (choose either Method A or Method B):

   Method A - Directly In-Game (Recommended):
   - Type /bqt to open settings and select "Audio".
   - Scroll to "Custom Audio Files".
   - Type your filename (e.g. fart.ogg) into the text box and click "Add Sound".
   - Your sound will immediately appear in the "Quest Complete Sound" and "Objective Progress Sound" dropdowns as:
     Custom 1 (fart.ogg), Custom 2 (cheer.ogg), etc.
   - Only your registered custom sounds are shown in the dropdown (no 1-99 clutter!).

   Method B - Text File Editing:
   - Open Media\CustomSounds.lua in any text editor.
   - Add your filename to the list:
     NullgateCustomSounds = {
         "fart.ogg",
         "cheer.ogg",
     }
   - Launch WoW. Your custom sounds will automatically appear in the sound dropdowns as:
     Custom 1 (fart.ogg), Custom 2 (cheer.ogg), etc.

Supported Audio Formats:
- Only Ogg Vorbis (.ogg) and MP3 (.mp3) files are supported.
- .wav files are no longer supported. Convert them to .ogg and keep the same name
  (e.g. fart.wav -> fart.ogg); settings that pointed at the .wav file use the .ogg automatically.

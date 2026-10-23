-- Nullgate's Quest Tracker - Custom Sounds Registration
--
-- Instructions:
-- 1. Place your custom .ogg or .mp3 audio files in this folder (Media\Sounds\).
-- 2. Only .ogg (Ogg Vorbis) and .mp3 files are supported. Convert any .wav files to .ogg
--    (keep the same name, e.g. fart.wav -> fart.ogg).
-- 3. Add your filenames to the NullgateCustomSounds table below (e.g. "fart.ogg", "cheer.ogg").
-- 4. Completely restart the World of Warcraft client so the engine indexes the new files.
--
-- Note: You can also add, preview, and remove custom sounds directly in-game via:
-- Interface Options -> AddOns -> Nullgate's Quest Tracker -> Audio -> Custom Audio Files

NullgateCustomSounds = NullgateCustomSounds or {}

-- Examples (uncomment to activate if you have placed these files in Media\Sounds\):
-- table.insert(NullgateCustomSounds, "fart.ogg")
-- table.insert(NullgateCustomSounds, "cheer.ogg")


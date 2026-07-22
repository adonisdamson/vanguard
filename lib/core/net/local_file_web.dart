// Web has no persistent local file paths (image_picker yields transient blob
// URLs), so an offline-queued photo can never be re-read here.
bool localFileExists(String path) => false;

unit PluginConsts;

interface

const

  PLUGIN_TITLE_SHORT = 'TCBox';
  PLUGIN_VERSION_TEXT = '0.5';

  PLUGIN_HELLO_TITLE_SHORT = PLUGIN_TITLE_SHORT + ' ' + PLUGIN_VERSION_TEXT;
  ACESS_KEY_SIGNATURE_STRING = 'TCBox1_';
  PLUGIN_ACCESS_KEY_FILENAME = 'key.txt';
  PLUGIN_LOG_FILENAME = 'TCBOX.log';
  PLUGIN_SETTINGS_FILENAME = 'settings.ini';
  PLUGIN_LANGUAGE_CODES_PATH = 'locale\languagecodes.mo';

  // minimum filesize to upload with ChunkedUploader
  PLUGIN_BIGFILE_SIZE = 100 * 1024 * 1024;
  PLUGIN_CHUNK_SIZE = 4 * 1024 * 1024;

resourcestring
  PLUGIN_TITLE = 'Total Commander Dropbox plugin';

function getPluginHelloTitle(): string;

implementation

function getPluginHelloTitle(): string;
begin
  Result := PLUGIN_TITLE + ' ' + PLUGIN_VERSION_TEXT;
end;

end.

GNU_MSGFMT="C:\Program Files\Poedit\bin\msgfmt.exe"
DOMAIN = default
# The definitions below are derived from the definitions above.
# You could also override them.
LOCALE_DIR = locale
LANG_RU = ru
TRANSLATE_PO = $(DOMAIN).po
TRANSLATE_MO = $(DOMAIN).mo
LRU = $(LOCALE_DIR)\$(LANG_RU)\LC_MESSAGES
LRU_PO = $(LRU)\$(TRANSLATE_PO)
LRU_MO = $(LRU)\$(TRANSLATE_MO)

ziptcbox: tcbox
	python zip.py tcbox.zip pluginst.inf  ../ssleay32.dll ../libeay32.dll ../TCBox.wfx locale
tcbox: locale
locale: locale_ru locale_lang_codes
locale_ru:
	if not exist "$(LRU)" md "$(LRU)"
	$(GNU_MSGFMT) ..\$(LRU_PO) -o $(LRU_MO)
	COPY ..\$(LRU_PO) $(LRU_PO) > NUL
locale_lang_codes:
	$(GNU_MSGFMT) ..\$(LOCALE_DIR)\languagecodes.po -o $(LOCALE_DIR)\languagecodes.mo
clear:
	DEL tcbox.zip
	RD  /S /Q locale
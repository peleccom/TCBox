GNU_MSGFMT="C:\Program Files\Poedit\bin\msgfmt.exe"
DOMAIN = default
# The definitions below are derived from the definitions above.
# You could also override them.
LOCALE_DIR = locale
LANG_RU = ru
LANG_EN = en
TRANSLATE_PO = $(DOMAIN).po
TRANSLATE_MO = $(DOMAIN).mo
LRU = $(LOCALE_DIR)\$(LANG_RU)\LC_MESSAGES
LRU_PO = $(LRU)\$(TRANSLATE_PO)
LRU_MO = $(LRU)\$(TRANSLATE_MO)
LEN = $(LOCALE_DIR)\$(LANG_EN)\LC_MESSAGES
LEN_PO = $(LEN)\$(TRANSLATE_PO)
LEN_MO = $(LEN)\$(TRANSLATE_MO)
LANG_CODES_MO = $(LOCALE_DIR)/languagecodes.mo
LANG_CODES_PO = $(LOCALE_DIR)/languagecodes.po

tcbox: ziptcbox
ziptcbox: ../tcbox.wfx locale
	python zip.py tcbox.zip pluginst.inf  ../ssleay32.dll ../libeay32.dll ../TCBox.wfx locale
locale:  $(LRU_MO) $(LRU_PO) $(LEN_MO) $(LANG_CODES_MO) 
$(LRU_PO): ..\$(LRU_PO)
	COPY ..\$(LRU_PO) $(LRU_PO) > NUL
$(LEN_MO): ..\$(LEN_PO)
	if not exist "$(LEN)" md "$(LEN)"
	$(GNU_MSGFMT) ..\$(LEN_PO) -o $(LEN_MO)
$(LRU_MO): ..\$(LRU_PO)
	if not exist "$(LRU)" md "$(LRU)"
	$(GNU_MSGFMT) ..\$(LRU_PO) -o $(LRU_MO)
$(LANG_CODES_MO): ..\$(LANG_CODES_PO)
	$(GNU_MSGFMT) ..\$(LANG_CODES_PO) -o $(LANG_CODES_MO)
../tcbox.wfx: ../*.pas ../*.dfm ../*.res ../*.rc ../*.ico ../*.gif ../*.dpr
	build_wfx.bat
clear:
	DEL tcbox.zip
	RD  /S /Q locale
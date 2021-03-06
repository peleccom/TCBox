{ Define flags for different Delphi versions }

{$IFDEF VER120}  { Delphi 4 }
{$DEFINE DELPHI4}
{$DEFINE DELPHI4_UP}
{$ENDIF}

{$IFDEF VER130}  { Delphi 5 }
{$DEFINE DELPHI5}
{$DEFINE DELPHI4_UP}
{$DEFINE DELPHI5_UP}
{$ENDIF}

{$IFDEF VER140}  { Delphi 6 }
{$DEFINE DELPHI6}
{$DEFINE DELPHI4_UP}
{$DEFINE DELPHI5_UP}
{$DEFINE DELPHI6_UP}
{$ENDIF}

{$IFDEF VER150}  { Delphi 7 }
{$DEFINE DELPHI7}
{$DEFINE DELPHI4_UP}
{$DEFINE DELPHI5_UP}
{$DEFINE DELPHI6_UP}
{$DEFINE DELPHI7_UP}
{$ENDIF}

{$IFDEF VER170}  { Delphi 2005 }
{$DEFINE DELPHI9}
{$DEFINE DELPHI4_UP}
{$DEFINE DELPHI5_UP}
{$DEFINE DELPHI6_UP}
{$DEFINE DELPHI7_UP}
{$ENDIF}

{$IFDEF VER180}  { Delphi 2006 }
{$DEFINE DELPHI10}
{$DEFINE DELPHI4_UP}
{$DEFINE DELPHI5_UP}
{$DEFINE DELPHI6_UP}
{$DEFINE DELPHI7_UP}

{$ENDIF}

{$IFDEF VER230}  { Delphi XE2 }
{$DEFINE DELPHIXE2}
{$DEFINE DELPHI4_UP}
{$DEFINE DELPHI5_UP}
{$DEFINE DELPHI6_UP}
{$DEFINE DELPHI7_UP}

{$ENDIF}
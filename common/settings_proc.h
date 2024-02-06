/* Copyright 2012 Kjetil S. Matheussen

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program; if not, write to the Free Software
Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA  02111-1307, USA. */


#ifndef SETTINGS_PROC_H
#define SETTINGS_PROC_H

#ifdef __cplusplus
namespace radium{
  struct ResetSettings{
    bool reset_main_config_file;
    bool reset_soundcard_config;
    bool reset_color_config_file;
    bool clean_plugin_cache;
    bool reset_keyboard_configuration;
    bool clean_mod_samples;
    bool clean_xi_samples;
  };
}
#endif

extern LANGSPEC bool SETTINGS_has_key(const char *key);

extern LANGSPEC bool SETTINGS_read_bool(const char *key, bool def);
extern LANGSPEC int64_t SETTINGS_read_int(const char *key, int64_t def); // Warning, not cached yet!
extern LANGSPEC int SETTINGS_read_int32(const char *key, int def); // Warning, not cached yet!
extern LANGSPEC double SETTINGS_read_double(const char *key, double def); // Warning, not cached yet!
extern LANGSPEC const char *SETTINGS_read_string(const char *key, const char *def); // Warning, not cached yet!

extern LANGSPEC const wchar_t* SETTINGS_read_wchars(const char* key, const wchar_t* def); // Warning, not cached yet!
extern LANGSPEC void SETTINGS_write_wchars(const char* key, const wchar_t *wchars);

extern LANGSPEC vector_t *SETTINGS_get_all_lines_starting_with(const char *prefix);

extern LANGSPEC void SETTINGS_write_bool(const char *key, bool val);
extern LANGSPEC void SETTINGS_write_int(const char *key, int64_t val);
extern LANGSPEC void SETTINGS_write_double(const char *key, double val);
extern LANGSPEC void SETTINGS_write_string(const char *key, const char *val);

extern LANGSPEC bool SETTINGS_remove(const char* key);

#ifdef __cplusplus
extern void SETTINGS_delete_configuration(const radium::ResetSettings &rs);
#endif

extern LANGSPEC void SETTINGS_init(void);

#ifdef USE_QT4
#include <QString>
extern void SETTINGS_set_custom_configfile(filepath_t filename);
extern void SETTINGS_unset_custom_configfile(void);
extern void SETTINGS_write_string(const char *key, QString val);
extern void SETTINGS_write_string(QString key, const char *val);
extern void SETTINGS_write_string(QString key, QString val);
extern QString SETTINGS_read_qstring(const char *key, QString def);
extern QString SETTINGS_read_qstring(QString key, QString def);
#endif

extern LANGSPEC void PREFERENCES_open(void); // open gui
extern LANGSPEC void PREFERENCES_open_MIDI(void);
extern LANGSPEC void PREFERENCES_open_sequencer(void);
extern LANGSPEC void PREFERENCES_update(void);

#endif

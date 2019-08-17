--  Generated by utildgen.c from system includes
with System;
with Interfaces.C;
package Util.Systems.Types is

   subtype dev_t is Interfaces.C.unsigned;
   subtype ino_t is Interfaces.C.unsigned_short;
   subtype off_t is Long_Long_Integer;
   subtype uid_t is Interfaces.C.unsigned_short;
   subtype gid_t is Interfaces.C.unsigned_short;
   subtype nlink_t is Interfaces.C.unsigned_short;
   subtype mode_t is Interfaces.C.unsigned_short;

   S_IFMT   : constant mode_t := 8#00170000#;
   S_IFDIR  : constant mode_t := 8#00040000#;
   S_IFCHR  : constant mode_t := 8#00020000#;
   S_IFBLK  : constant mode_t := 8#00030000#;
   S_IFREG  : constant mode_t := 8#00100000#;
   S_IFIFO  : constant mode_t := 8#00010000#;
   S_IFLNK  : constant mode_t := 8#00000000#;
   S_IFSOCK : constant mode_t := 8#00000000#;
   S_ISUID  : constant mode_t := 8#00000000#;
   S_ISGID  : constant mode_t := 8#00000000#;
   S_IREAD  : constant mode_t := 8#00000400#;
   S_IWRITE : constant mode_t := 8#00000200#;
   S_IEXEC  : constant mode_t := 8#00000100#;

   --  The windows HANDLE is defined as a void* in the C API.
   subtype HANDLE is System.Address;
   subtype File_Type is HANDLE;
   subtype Time_Type is Long_Long_Integer;

   type Timespec is record
      tv_sec  : Time_Type;
   end record;
   pragma Convention (C_Pass_By_Copy, Timespec);

   type Seek_Mode is (SEEK_SET, SEEK_CUR, SEEK_END);
   for Seek_Mode use (SEEK_SET => 0, SEEK_CUR => 1, SEEK_END => 2);

   type Stat_Type is record
      st_dev      : dev_t;
      st_ino      : ino_t;
      st_mode     : mode_t;
      st_nlink    : nlink_t;
      st_uid      : uid_t;
      st_gid      : gid_t;
      st_rdev     : dev_t;
      st_size     : off_t;
      st_atime    : Time_Type;
      st_mtime    : Time_Type;
      st_ctime    : Time_Type;
   end record;
   pragma Convention (C_Pass_By_Copy, Stat_Type);


end Util.Systems.Types;

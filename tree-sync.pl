#!/usr/bin/perl -w

=head1 NAME

tree-sync.pl - sync two directories recursively. The goal is to bring two trees exactly the same. However, tree-sync.pl does not perform any copy operation by default (it generates a command file instead). The user has the opportunity to exam the command file before real copy operations happen.

=head1 VERSION
Version 2.4 Modified $Date: 2008/10/26 20:58:00 $ 

=head1 DESCRIPTION

This script compares two directories recursively and print out a report.
A batch file that can sync two trees is also generated. 

Run "tree-sync.pl -help" to find out command-line options.

=head1 README

tree-sync.pl - sync two directories recursively. The goal is to bring two trees exactly the same. 
However, tree-sync.pl does not perform any copy operation by default (it generates a command file instead).
The user has the opportunity to exam the command file before real copy operations happen.

Run "tree-sync.pl -help" to find out command-line options.

To download, visit: 
  http://www.perl.com/CPAN 
  http://www.perl.com/CPAN/authors/id/P/PA/PAULPG/tree-sync/
Sources are now managed on github.com. To download, or join the project, visit:
  http://github.com/tardate/tree-sync/
  
  
Release 1 by Chang Liu (liu@ics.uci.edu | changliu@acm.org)
Copyright (c) 2000 Chang  Liu. All rights reserved.  
License: GPL: GNU General Public License (http://www.gnu.org/copyleft/gpl.html). 

Release 2.0-2.2 by Paul Gallagher (gallagher.paul@gmail.com)
Note: since attempts to contact the author of Release 1 have unfortunately failed
      to date, this version has been released without review from the original author.

Release 2.3 by Dave Stafford (dave.stafford@globis.net)

Release 2.4 by incorporates changes by Dave Stafford (dave.stafford@globis.net)
      and Paul Gallagher (gallagher.paul@gmail.com)


=head1 SYNCHRONISATION RULES

Normal (full bi-directional) sync:
   Used in situations where modifications may done in both
   the SOURCE and DEST locations and you want them to be
   kept in sync
+------------+-------------+-----------+---------------+
|  A:Source  |  B:Dest     |  Type     |  Action       |
+------------+-------------+-----------+---------------+
| exists     | not exist   | File      | copy A -> B   |
| exists     | not exist   | Directory | mkdir B       |
| not exist  | exists      | File      | unlink B      |
| not exist  | exists      | Directory | rmdir B       |
| newer      | older       | File      | copy A -> B   |
| older      | newer       | File      | copy B -> A   |
+------------+-------------+-----------+---------------+
Forward-only sync:
   Used in situations where modifications are only done
    in SOURCE and you want DEST to be a perfect mirror
+------------+-------------+-----------+---------------+
|  A:Source  |  B:Dest     |  Type     |  Action       |
+------------+-------------+-----------+---------------+
| exists     | not exist   | File      | copy A -> B   |
| exists     | not exist   | Directory | mkdir B       |
| not exist  | exists      | File      | no action     |
| not exist  | exists      | Directory | no action     |
| newer      | older       | File      | copy A -> B   |
| older      | newer       | File      | warning       |
+------------+-------------+-----------+---------------+

Sync Notes:
1. Time differences on directories are ignored
2. Files are considered 'changed' if modified time difference is greater than $mtimeDiffTolerance (currently 2secs)
3. File system time granularity varies by file system

            File System             File time granularity
           -----------------------------------------------
            FAT12/FAT16/FAT32            2 sec             see: http://en.wikipedia.org/wiki/File_Allocation_Table
            NTFS                       100 nsec
            Unix/Linux                   1 sec


=head1 CHANGES

From Version 2.3 to Version 2.4:

Refinements for 'ignore' operation.
Moved to github hosting
Introduced read-only file handling

 
From Version 2.2 to Version 2.3:

Added option 'diff' to view only changes 
Added option 'ignore' to exclude certain extensions
Added option 'brief' to remove src/dst directories in report view to make cleaner output


From Version 2.1 to Version 2.2:

1. fixed handling of filenames that contain special characters such as @, $ and quotes
2. fixed handling of filenames that contain regex special characters


From Version 2.0 to Version 2.1:

1. changed copy routine to force a copy of access/modified times. This change was needed because I discovered modification
   times are not copied automatically on most	filesystems (other than windows).


From Version 1.0 to Version 2.0:

1. fixed report width calculations
2. changed search algorithm to do forward/reverse tree traversal to avoid sort-based comparison issues
3. added -run option to allow immediate sync
4. added futz factor for file modified time comparison (if diff is less than $mtimeDiffTolerance, files are considered identical) 
   (exact copies on different filesystems may have minor variation in modified time due to different file system time granularity 
   e.g. from NTFS to FAT32 on the same system, can see a 2 sec diff in modified time)
5. added -syncmode parameter to allow choice of sync mode (currently supporting full or forward-only)
6. added use strict
7. verified works with relative source and dest paths

Limitations/known issues:
1. os is a redundant parameter. left in place for now.
2. internationalisation ... cannot handle Japanese filenames for example (under Windows XP with ActiveState Perl 5.8.8)
3. perhaps could do with a "mirror/accumulate" option, with additions to both source and dest copied. Unless we record sync state
   however, this would mean nothing could ever be deleted (it would always be copied back from the other side)!

=head1 PREREQUISITES

Getopt::Long
File::Find
File::Basename
File::stat
File::Copy

=head1 COREQUISITES

=pod OSNAMES

any

=pod SCRIPT CATEGORIES

CPAN/Administrative
CPAN

=head2 Examples

 %perl tree-sync.pl /home/chang/work/prj /mnt/f/backup/prj

or (relative path)

 %perl tree-sync.pl /home/chang/work/prj ../backup/prj

or (in a shell)
 
  C:/work>perl tree-sync.pl c:/work/prj d:/backup/prj

or (in DOS)

  C:\work>perl tree-sync.pl c:\work\prj d:\backup\prj

=head1 ENVIRONMENT VARIABLES

nil

=head1 SYMBOLS

A <- B : B overwrite A
A -> B : A overwrite B
A ->   : copy A
  <- B : copy B
A == B : files in sync
A <> B : A and B are different, but not updated due to sync settings
A XX   : remove A
name/  : it is a directory

=cut

use strict;
use warnings;

my $VERSION = 2.4;

############# USAGE ##############################
#
#

sub usage
{
	my ($msg) = @_;
	if ($msg) {
		print "\nWARNING: $msg\n";
	}
    print <<END_OF_USAGE;

PURPOSE: Synchronize two directory trees.

USAGE:
    perl tree-sync.pl OPTIONS DIR1 DIR2

OPTIONS:
    [-debug]       default is false
    [-brief]       make report cleaner by removing src/dst directories
    [-ignore EXT]  comma separated list of extensions to ignore
    [-verbose]     default is false
    [-diff]        show only differences. Default is false
    [-force | -noforce] forces overwrite of read-only files. Default is -force
    [-cmd SYNC-CMD-FILENAME] default is sync-now.pl. 
    [-run]         runs the sync routine immediately, overrides -cmd option. default is false
    [-width SCREEN-WIDTH] default is 80
    [-syncmode [full|fwdonly]] default is full.
    [-help]

PARAMETERS:
    DIR1 = source directory. Must exist and be a directory specification
    DIR2 = target directory. Must be a directory. Will br created if it does not exist.

EXAMPLE:
    c:/> perl tree-sync.pl -run -force "c:\\My Documents" d:\\backup\\mydocs
or
    % perl tree-sync.pl -cmd mysync.pl -width 200 -verbose /home/chang/work/prj /mnt/f/backup/prj

After that:
    % cat sync-now.pl
    % perl sync-now.pl
    
NOTE:
It is recommended you DO NOT use the -run option until you have first tested using -cmd.
Review the generated script file and report to verify that the sync is performing correctly.


END_OF_USAGE

	print "Version: $VERSION   ".'Last modified: $Date: 2008/10/26 20:58:00 $'."\n";
    exit;
}

#
#
############# END OF USAGE #########################

use Getopt::Long;
use File::Find;
use File::Basename;
use File::stat;
use File::Copy;

############# Command Line options processing and default values ##################
#
# If you want to change the default behavior of this script, modify the values here
#

my $opt_verbose;
my $opt_debug;
my $opt_cmd = "sync-now.pl";
my $opt_syncmode = "full";
my $opt_width = 80;
my $opt_os = "DOS";
my $opt_help;
my $opt_run;
my $opt_diff;
my $opt_ignore;
my $opt_brief;
my $opt_force = 1;
my $mtimeDiffTolerance = 2;

GetOptions("verbose" => \$opt_verbose,
           "debug" => \$opt_debug,
           "cmd=s" => \$opt_cmd,
           "syncmode=s" => \$opt_syncmode,
           "width=s" => \$opt_width,
           "os=s" => \$opt_os,
           "help" => \$opt_help,
           "run" => \$opt_run,
           "brief" => \$opt_brief,
           "diff" => \$opt_diff,
           "ignore=s" => \$opt_ignore,
           "force!" => \$opt_force
	   );

print "DEBUG:tree-sync.pl VERSION: $VERSION\n" if $opt_debug;

usage() if $opt_help;

## ADDED DGS if a list of extensions to ignore have been provided create a reg exp
if ($opt_ignore) {
	  $opt_ignore=~s/;|,/\$\|/g;
	  $opt_ignore.='$';
}
## END ADDED DGS

my $sourceDirectory = shift or usage("Source not specified");
my $targetDirectory = shift or usage("Target not specified");

# force paths to use  "/" not "\"
$sourceDirectory =~ s/\\/\//g;
$targetDirectory =~ s/\\/\//g;

# check source is a directory
if (!-d "$sourceDirectory" ) { usage("source is not a directory") };
# check dest is a dir if it exists
if ((-e "$targetDirectory" ) && (!-d "$targetDirectory" )) { usage("target is not a directory") };

# force paths to end in "/"
$sourceDirectory .= ( $sourceDirectory =~ /.*\/$/ ) ? "" : "/";
$targetDirectory .= ( $targetDirectory =~ /.*\/$/ ) ? "" : "/";

print "\$sourceDirectory = [$sourceDirectory]\n" if $opt_debug;
print "\$targetDirectory = [$targetDirectory]\n" if $opt_debug;

#
#
########### END OF Command Line Options ###############



########### START report format definition ############
#
    my $format = "format STDOUT_TOP =\n";
    my $i ;

    $format = $format . "DIR 1:\@";
    for ($i=0; $i< $opt_width/2 -2 -7; $i++)
    {
	$format = $format . "<";
    }
    $format = $format . "    DIR 2:\@";
    for ($i=0; $i< $opt_width/2 -2 -7 ; $i++)
    {
	$format = $format . "<";
    }
    $format = $format . "\n";
    $format = $format . "\$sourceDirectory, \$targetDirectory\n";
    for ($i=0; $i< $opt_width ; $i++)
    {
	$format = $format . "-";
    }
    $format = $format . "\n.\n";

    $format = $format . "format STDOUT=\n";
    $format = $format . "\@";
    for ($i=0; $i< $opt_width/2 -2 -1; $i++)
    {
	$format = $format . "<";
    }
    $format = $format . " \@< \@";
    for ($i=0; $i< $opt_width/2 -2 -1; $i++)
    {
	$format = $format . "<";
    }
    $format = $format . "\n";
    $format = $format . "\$left, \$op, \$right\n";
    $format = $format . ".\n";

    print $format if $opt_debug;

# Here's what these two format will look like if width is 80:
#
#format STDOUT_TOP=
##        1         2         3         4         5         6         7         8
##2345678901234567890123456789012345678901234567890123456789012345678901234567890
#DIR 1:@<<<<<<<<<<<                      DIR 2:@<<<<<<<<<<<<<<<
#      $sourceDirectory,                       $targetDirectory
#-------------------------------------------------------------------------------
#.
#
#format =
##        1         2         3         4         5         6         7         8
##2345678901234567890123456789012345678901234567890123456789012345678901234567890
#@<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<< @< @<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
#$left,                                $op, $right
#.

#
#
########### END report format definition ##############


my $left;
my $right;
my $op;

eval $format;
die $@ if $@;

my $count_files = 0;
my $count_dirs = 0;
my $count_diffs = 0;

# params:
# 1: left 
# 2: op
# 3: right
# 4: file [0] or directory [1] or informational [2]
# 5: count differences [0,1]
sub report
{
	$left = shift;
	$op = shift;
	$right = shift;
	my $type = shift;
	my $diff = shift;
  return if $type==1 && $opt_brief;

  $left=~s/$sourceDirectory//  if $opt_brief;
  $right=~s/$targetDirectory// if $opt_brief;

	if ($type == 0) {
		$count_files ++;
		$count_diffs += $diff;
	} elsif ($type == 1) {
		$count_dirs ++;
		$count_diffs += $diff;
	}
	write;
	return;
}


my $syncSource;
my $syncDest;
my $syncDirection;	# "forward" or "reverse"
my @syncCmds;		# array of commands to perform
my @syncDelDirs;	# array of directories to delete (processed last)

# procedure do_sync
# params: nil ($File::Find::name will be current file)
# sync rules:
# 0. source always exists
# 1. if syncDirection="forward", source is a file, and dest doesn't exist, copy source to dest [action=copysrcf]
# 2. if syncDirection="forward", source is a directory, and dest doesn't exist, create dest directory [action=adddestd]
# 3. if syncDirection="reverse", source is a file, and dest doesn't exist, delete source [action=delsrcf]
# 4. if syncDirection="reverse", source is a directory, and dest doesn't exist, delete source [action=delsrcd]
# 5. if syncDirection="forward", source and dest exist and are files, and source is newer (by modified time), copy source to dest [action=copysrcf]
# 6. if syncDirection="forward", source and dest exist and are files, and dest is newer (by modified time), copy dest to source [action=copydestf]
#
sub do_sync
{
	my $action = "none"; # options: delsrcf, delsrcfd, adddestd, copysrcf, copydestd, none

	my $name = $File::Find::name;
	
	##ADDED DGS  - option to ignore unwanted file extensions
	if ($opt_ignore && $name=~$opt_ignore) {
		  print "Ignoring $name\n" if ($opt_debug || $opt_verbose);
		  return;
	}
	
	print "          \$name: [$name]\n" if ($opt_debug || $opt_verbose);
	if ($syncSource =~ /\Q$name/) {
		report ("$name", "", "(root directory - no action)",2,0) if ($opt_debug || $opt_verbose);
		print "\n" if ($opt_debug || $opt_verbose);
		return;
	}

	my $dirname = dirname($name);
	$dirname .= ( $dirname =~ /.*\/$/ ) ? "" : "/"; # make sure the directory ends in "/" (cater for Windows root directories)
	print "       \$dirname: [$dirname]\n" if ($opt_debug || $opt_verbose);

	(my $reldir = $dirname) =~ s/$syncSource//;
	print "        \$reldir: [$reldir]\n" if ($opt_debug || $opt_verbose);

	my $filename = basename($name);
	print "      \$filename: [$filename]\n" if $opt_debug;

	my $sister = $syncDest.$reldir.$filename;
	print "        \$sister: [$sister]\n" if $opt_debug;

	my $fileExists = (-e "$name" ) ? 1 : 0;
	my $fileIsDir = (-d "$name" ) ? 1 : 0;
	my $sisterExists = (-e "$sister" ) ? 1 : 0;
	my $sisterIsDir = (-d "$sister" ) ? 1 : 0;

	my $fileMtime = 0;
	my $fileMtimeS = "";
	if ($fileExists) {
		my $fileStat = stat($name);
		$fileMtime=$fileStat->mtime;
		$fileMtimeS = scalar(localtime($fileMtime));
	} else {
		# houston, we have a problem ... 
		report ("$name", "XX", "ERROR: source file not found",2,0);
		print "\n" if ($opt_debug || $opt_verbose);
		return;
	}
	my $sisterMtime = 0;
	my $sisterMtimeS = "";
	if ($sisterExists) {

		if ($syncDirection ne "forward") {
			# skip for reverse match
			report ("$name", "", "(no action required during reverse match)",2,0) if ($opt_debug || $opt_verbose);
			print "\n" if ($opt_debug || $opt_verbose);
			return
		}

		if ($fileIsDir != $sisterIsDir) {
			# houston, we have another problem ...
			report ("$name", "XX", "ERROR: source is directory=[$fileIsDir], dest is directory=[$sisterIsDir]",2,0);
			print "\n" if ($opt_debug || $opt_verbose);
			return;
		}

		my $sisterStat = stat($sister);
		$sisterMtime=$sisterStat->mtime;
		$sisterMtimeS = scalar(localtime($sisterMtime));

		my $mtimeDiff = $fileMtime - $sisterMtime;

		if ($mtimeDiff > $mtimeDiffTolerance) {
			$action = ($fileIsDir) ? "copysrcd" : "copysrcf";
		} elsif ($mtimeDiff < -$mtimeDiffTolerance) {
			$action = "copydest";
			$action = ($sisterIsDir) ? "copydestd" : "copydestf";
		} else {
			$action = "none";
		}

	} else {
		if ($syncDirection eq "forward") {
			$action = ($fileIsDir) ? "adddestd" : "copysrcf";
		} else {
			$action = ($fileIsDir) ? "delsrcd" : "delsrcf";
		}
	}



	print "      \$filename: [$filename]\n" if ($opt_debug || $opt_verbose);
	print "         exists: [$fileExists]\n" if ($opt_debug || $opt_verbose);
	print "      directory: [$fileIsDir]\n" if ($opt_debug || $opt_verbose);
	print "          mtime: [$fileMtimeS] [$fileMtime]\n" if ($opt_debug || $opt_verbose);

	print "        \$sister: [$sister]\n" if ($opt_debug || $opt_verbose);
	print "         exists: [$sisterExists]\n" if ($opt_debug || $opt_verbose);
	print "      directory: [$sisterIsDir]\n" if ($opt_debug || $opt_verbose);
	print "          mtime: [$sisterMtimeS] [$sisterMtime]\n" if ($opt_debug || $opt_verbose);
	print "         action: [$action]\n" if ($opt_debug || $opt_verbose);

	my $cmd;

	if ($action eq "delsrcf") {
		report ("$name", "XX", "(removing source file)", $fileIsDir, 1);
		$cmd = "unlink ( \"\Q$name\E\" );\n";
		push (@syncCmds, $cmd);

	} elsif ($action eq "delsrcd") {
		report ("$name", "XX", "(removing source directory)", $fileIsDir, 1);
		push (@syncDelDirs, $name);

	} elsif ($action eq "adddestd") {
		report ("$name", "->", "$sister", $fileIsDir, 1);
	    $cmd = "mkdir \"\Q$sister\E\";\n";
		push (@syncCmds, $cmd);

	} elsif ($action eq "copysrcf") {
		report ("$name", "->", "$sister", $fileIsDir, 1);
	    $cmd = "copyWithTime( \"\Q$name\E\", \"\Q$sister\E\" );\n";
		push (@syncCmds, $cmd);

	} elsif ($action eq "copydestf") {
		if ( $opt_syncmode =~ /full/i ) {
			report ("$name", "<-", "$sister", $fileIsDir, 1);
		    $cmd = "copyWithTime( \"\Q$sister\E\", \"\Q$name\E\" );\n";
			push (@syncCmds, $cmd);
		} else {
			report ("$name", "<>", " (dest is newer, not updated) $sister", $fileIsDir, 0);
		}

	} else {
		# implied: none
		### ADDED DGS - added unless $opt_diff
		report ("$name", "==", "$sister", $fileIsDir, 0) unless $opt_diff;

	} 
	
	print "\n" if ($opt_debug || $opt_verbose);
	return;
}

# creates the sync script 
# NB: must run after first running do_sync
#
sub create_sync_script
{

	print "Generating commands to the command file [$opt_cmd]...\n" if $opt_verbose;

	open(CMD,">$opt_cmd") or die "Can't open command file [$opt_cmd] to write.\n";
	print CMD <<END_OF_PREAMBLE;
#!/usr/bin/perl -w
# This file is generated on ".scalar(localtime)." by tree-sync.pl to sync directories
# source: [$sourceDirectory] and dest: [$targetDirectory].
# Please do not edit.
#
use File::stat;
use File::Copy;
# subroutine to copy access/modified times from source to dest file
sub copyWithTime {
	my (\$srcFile, \$destFile) = \@_;
	my \$srcAtime=stat(\$srcFile)->atime;
	my \$srcMtime=stat(\$srcFile)->mtime; 
	# allow write on dest if file present
	chmod stat(\$destFile)->mode | 0222, \$destFile if ((-e "\$destFile" ) && !(-d "\$destFile" )); 
	copy(\$srcFile, \$destFile);
	utime \$srcAtime, \$srcMtime, \$destFile;
	return;
}
END_OF_PREAMBLE

	my $cmd;
	print CMD "\n#\n# sync files and directories:\n";
	while ($cmd = shift(@syncCmds) ) {
	    print CMD "$cmd";
	}
	print CMD "\n#\n# remove deleted directories:\n";
	while ($cmd = pop(@syncDelDirs) ) {
	    print CMD "rmdir \"$cmd\";\n";
	}

	close (CMD);

	print "\nThe generated command file $opt_cmd can bring these two directories in sync.\n";
	print "You can run it using command: perl \"$opt_cmd\"\n\n";
	return;
}

# executes immediate sync
# NB: must run after first running do_sync
#
sub exec_sync
{
	print "\nExecuting immediate sync..\n";

	my $cmd;
	print "\n#\n# sync files and directories:\n";
	while ($cmd = shift(@syncCmds) ) {
		print "$cmd";
		eval $cmd;
	}
	print "\n#\n# remove deleted directories:\n";
	while ($cmd = pop(@syncDelDirs) ) {
		print "rmdir \"$cmd\";\n";
		rmdir "$cmd";
	}	
	print "\n..done.\n\n";
	return;
}

# sanity checks on source and dest directories
if (! -e $sourceDirectory) {
	print "\nERROR: source directory does not exist\n\n";
	exit;
}
if (! -e $targetDirectory) {
	report ("$sourceDirectory", "->", "$targetDirectory", 1, 1);
	push (@syncCmds, "mkdir \"$targetDirectory\";\n");
} else {
	### ADDED DGS - added unless $opt_diff
	report ("$sourceDirectory", "==", "$targetDirectory", 1, 0) unless $opt_diff;
}

# sync forward .. .from source to dest
$syncDirection = "forward";
$syncSource = $sourceDirectory;
$syncDest = $targetDirectory;
print "\nsync $syncDirection from [$syncSource] to [$syncDest] ...\n" if ($opt_debug || $opt_verbose);
push @syncCmds, "\n#\n# sync $syncDirection from [$syncSource] to [$syncDest] ...\n";
find({ wanted => \&do_sync, no_chdir => 1 }, $syncSource);

# now sync in reverse .. .from dest to source [but only if dest already exists and if full sync mode]
if (-e "$targetDirectory" && ( $opt_syncmode =~ /full/i ) ) {
	$syncDirection = "reverse";
	$syncSource = $targetDirectory;
	$syncDest = $sourceDirectory;
	print "\nsync $syncDirection from [$syncSource] to [$syncDest] ...\n" if ($opt_debug || $opt_verbose);
	push @syncCmds, "\n#\n# sync $syncDirection from [$syncSource] to [$syncDest] ...\n";
	find({ wanted => \&do_sync, no_chdir => 1 },  $syncSource);
}

    
print "\n\nDirectories : $count_dirs\n";
print "Files       : $count_files\n";
print "Differences : $count_diffs\n";

if ($count_diffs == 0) {
	print "\nSource and destination are in sync ... nothing to do.\n\n";
	exit;
}

if ($opt_run) {
	exec_sync;

} else {
	create_sync_script;

}

1;

# subroutine to copy file with access/modified times from source to dest file
sub copyWithTime {
	my ($srcFile, $destFile) = @_;
	my $srcAtime=stat($srcFile)->atime;
	my $srcMtime=stat($srcFile)->mtime;
	# allow write on dest if file present and "force" specified
	chmod stat($destFile)->mode | 0222, $destFile if (($opt_force) && (-e "$destFile" ) && !(-d "$destFile" )); 
	copy($srcFile, $destFile);
	utime $srcAtime, $srcMtime, $destFile;
	return;
}

package OSGCerts;

=head1 OSGCerts

OSGCerts - helpful functions for OSG CA Certificate scripts

=head1 SYNOPSIS

    use OSGCerts;

=head1 DESCRIPTION

We have at least three scripts that share these subroutines, so we
are collecting this code in a module rather than duplicating it.

=head1 METHODS

=over 4

=cut

use strict;
use warnings;
use File::Temp qw/ tempdir /;
use File::Basename;
use FileHandle;

our @ISA = qw(Exporter);
our @EXPORT_OK = qw(log_msg);

# Global variables that get set during the initialize() sub
my $initialized = 0;
my $PACKAGE;
my $certs_version_file;
my $updater_status_file;
my $updater_conf_file;

# File handle for whichever log we are using
my $log_fh = undef;


sub initialize {
    ($PACKAGE) = @_;
    
    # Replace this with something?
    set_logfile("/var/log/$PACKAGE.system.out");

    $certs_version_file  = "/var/lib/osg-ca-certs/ca-certs-version";
    $updater_status_file = "/var/lib/osg-ca-certs/certs-updater-status";
    $updater_conf_file   = "/etc/osg/osg-update-certs.conf";
    $initialized = 1;
}


sub parse_certs_updater_status_file {
    my %info;

    if(-r $updater_status_file) {
        foreach my $line (slurp($updater_status_file)) {
            next if($line =~ /^\s*\#/);  # skip comment line
            if($line =~ /^\s*(\w+)\s*-\s*(\S+)/) {
                $info{$1} = $2;
            }
        }
        return \%info;;
    }
    elsif(-e $updater_status_file) {
        log_msg("ERROR: Status file '$updater_status_file' is not readable.  Continuing.");
    }
    else {
        log_msg("Status file not found.  Creating status file '$updater_status_file'.");
        system("touch $updater_status_file");
    }
    return undef;
}

# Get the installed version of the certificates from the version file
sub get_installed_certs_version {
    my ($log) = @_;
    my $version;

    if (-r $certs_version_file) {
        $version = slurp($certs_version_file);
        chomp($version);
        log_msg("Installed certs version appears to be '$version'") if($log);
    } 
    else {
        $version = undef;
        log_msg("No certificates seem to be installed and owned by this instance of the OSG.") if($log);
    }

    return $version;
}


sub get_certs_version_file_loc {
    return $certs_version_file;
}

sub get_certs_updater_status_file_loc {
    return $updater_status_file;
}

sub get_updater_conf_file_loc {
    return $updater_conf_file;
}

# Logging subroutines
sub set_log_file_handle {
    $log_fh = shift;
}

sub set_logfile {
    my ($file) = @_;
    
    my $fh;
    if(!open($fh, '>>', $file)) {
	print STDERR "Warning: could not open log file for appending: $!\n";
	print STDERR "All log info will be written to STDOUT instead.\n";
	return undef;
    }
    else {
	set_log_file_handle($fh);
    }
}

sub log_msg {
    my (@msg) = @_;

    if(!defined($log_fh)) {
        print "@msg\n";
    }
    else {
        my $timestamp = log_timestamp();
        foreach my $line (@msg) {
            my $l = $line;
            chomp($l);
            print $log_fh "$timestamp $l\n";
        }
    }
}

sub log_timestamp {
    my ($sec,$min,$hour,$mday,$month,$year) = localtime(time);
    $month++;
    $year += 1900;
    return sprintf("%02d-%02d-%02dT%02d-%02d-%02d", $year, $month, $mday, $hour, $min, $sec);
}


#---------------------------------------------------------------------
#   
# wget: Download file from URL.
# Input  : (url, download_directory)
#   
#---------------------------------------------------------------------
sub wget {
    my ($url, $working_dir, $no_logging) = @_;
    
    if(!defined($no_logging)) {
        $no_logging = 0;
    }

    chomp(my $cwd = `pwd`);
    chdir($working_dir);
    
    my $wget_ret = system("wget $url -o $working_dir/wget.out");
    
    if(!$no_logging and defined($log_fh)) {
        my @get_out = slurp("$working_dir/wget.out");
        log_msg(@get_out);
    }

    unlink("$working_dir/wget.out");
        
   if($wget_ret != 0) {
        print "wget failure - Could not fetch file at '$url'.\n";
        return 1;
    }

    chdir($cwd);
    return 0;
}


#---------------------------------------------------------------------
#
# get_ca_description: Check if the certs_url is acceptable
# Input  : url(of cacerts)
# Output : Returns complete $description
#          $description->{valid} 0 - Validation Failed, 1 - Validation Succeeded
#
#
#---------------------------------------------------------------------
sub fetch_ca_description {
    my ($local_url, $working_dir) = @_;
    
    if(!$working_dir || !-w $working_dir) {
        $working_dir = tempdir("osgcert-XXXXXX", TMPDIR => 1, CLEANUP => 1);
    }

    my $description_file = "$working_dir/" . basename($local_url);
    my $description;
    
    wget($local_url, $working_dir);

    if (!-e $description_file) {
        log_msg("Description file does not exist.\n");
        $description->{valid} = 0;
        return $description;
    }

    # Read in the downloaded description file.
    my @contents = slurp($description_file);
    foreach my $line (@contents) {
        next if ($line =~ /^\s*$/);  # Skip blank lines
        next if ($line =~ /^\s*\#/); # Skip comments

        # The versiondesc attribute can have spaces, so parse accordingly
        if ($line =~ /^\s*(\w+)\s*=\s*(.+)$/) {
            my ($name, $value) = ($1, $2);
            $value =~ s/\#.*$//; # Strip off comments
            $value =~ s/\s+$//;  # Strip trailing whitespace
            $description->{$name} = $value;
        }
    }

    # Validate the description file
    my $missing_info = 0;
    if (!defined $description->{dataversion} || $description->{dataversion} != 1) {
        log_msg("Bad description: dataversion not specified or not equal to 1\n");
        $missing_info++;
    }

    if (!defined $description->{certsversion}) {
        log_msg("Bad description: certs version was not specified\n");
        $missing_info++;
    }

    if (!defined $description->{versiondesc}) {
        log_msg("Bad description: version description was not specified\n");
        $missing_info++;
    }

    if (!defined $description->{tarball}) {
        log_msg("Bad description: tarball was not specified\n");
        $missing_info++;
    }

    if (!defined $description->{tarball_md5sum}) {
        log_msg("Bad description: tarball_md5sum was not specified\n");
        $missing_info++;
    }

    if($missing_info != 0) {
        log_msg("The description file is incomplete.\n");
        $description->{valid} = 0;
    }
    else {
        $description->{valid} = 1;
    }

    return $description;
}

#---------------------------------------------------------------------
#
# read_updater_config_file: Read in the osg-update-certs.conf file 
#                           and populate $config variable.
# Input  : Config file location
# Output : A hash containing the config
#
#---------------------------------------------------------------------

## Config file will look similar to the following:
## 
## cacerts_url=http://some.url
## log=logfile
## include=<file to copy into certs>
## exclude=<file to remove from certs, if it exists> (DEPRECATED!)
## exclude_ca=<hash to remove from certs, if it exists>
## debug=[0,1]
## include, exclude, and exclude_ca can occur multiple times.
## comments are allowed

sub read_updater_config_file {

    if(!defined $updater_conf_file) {
        log_msg("The location of osg-update-certs.conf is not defined.\n");
        return undef;
    }

    my $config;

    # Defaults for anything we might not read.
    $config->{log} = "/var/log/osg-update-certs.log";
    $config->{cacerts_url} = "";
    $config->{debug} = 0;
    my @includes = ();
    my @excludes = ();
    my @exclude_cas = (); 

    if (!-e $updater_conf_file) {
        log_msg("Configuration file '$updater_conf_file' was not found.\n");
        return undef;
    }
    else {
        my @contents = slurp($updater_conf_file);
        foreach my $line (@contents) {
            next if ($line =~ /^\s*$/);  # Skip blank lines
            next if ($line =~ /^\s*\#/); # Skip comments

            if ($line =~ /^\s*cacerts_url\s*=\s*(\S+)/) {
                $config->{cacerts_url} = $1;
            }
	    elsif ($line =~ /^\s*install_dir\s*=\s*(\S+)/) {
		$config->{install_dir} = $1;
	    }
            elsif ($line =~ /^\s*log\s*=\s*(\S+)/) {
                $config->{log} = $1;
            }
            elsif ($line =~ /^\s*include\s*=\s*(\S+)/) {
                push(@includes, $1);
            }
            elsif ($line =~ /^\s*exclude\s*=\s*(\S+)/) {
                push(@excludes, $1);
            }
            elsif ($line =~ /^\s*exclude_ca\s*=\s*(\S+)/) {
                push(@exclude_cas, $1);
            }
            elsif ($line =~ /^\s*debug\s*=\s*(\S+)/) {
                $config->{debug} = $1;
            }
        }
    }
    $config->{includes} = \@includes;
    $config->{excludes} = \@excludes;
    $config->{exclude_cas} = \@exclude_cas;

    return $config;
}

sub which {
    my ($exe) = @_;

    foreach my $dir (split(/:/, $ENV{PATH})) {
        if (-x "$dir/$exe") {
            $dir =~ s|/+$||;  # Trim trailing slash on dir
            return "$dir/$exe";
        }
    }
    return "";
}

sub slurp {
    my ($file) = @_;

    log_msg("slurping $file");

    if (not -e $file) {
        log_msg("no such file");
        return undef;
    }

    my $fh = new FileHandle $file;
    if (not defined $fh) {
        log_msg("could not open file: $!");
        return undef;
    }

    my @contents = <$fh>;
    my $contents_as_string = join('', @contents);
    log_msg('read ' . length($contents_as_string) . ' characters');
    return wantarray ? @contents : $contents_as_string;
}


1;

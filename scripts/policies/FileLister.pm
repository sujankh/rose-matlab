package FileLister;
use strict;
use Carp;
use Cwd 'abs_path';

sub new {
  my($cls,@root) = @_;
  my $self = bless {build=>0,               # include build subtrees identified by presence of "include-staging"?
		    edg=>0,                 # enter the EDG_* directories containing C/C++ parser source code?
		    thirdparty=>0,          # software not "owned by" ROSE developers, other than EDG which is handled above
		    generated=>0,           # software that is machine-generated
		    install=>0,             # files in the ROSE install directory
		    recursive=>1,           # recurse into directories; -1=never; 0=only into specified dirs; 1=always
		    pending=>\@root,        # files and directories that are pending
		    gitdir=>git_toplevel(), # absolute name of top-level Git directory if we're inside a Git repo
		    gitfiles=>{},	    # mapping of all Git files to hashes if we're inside a Git repo
		   }, $cls;

  $self->{gitfiles} = git_files() if $self->{gitdir};
  
  # Parse switches (usually directly from the command-line)
  while (@root && $root[0]=~/^--?([_a-zA-Z]\w*)(=(.*))?/) {
    my($var,$val) = ($1,$3);
    $val = 1 unless defined $val;
    croak "unknown switch: --$var" unless exists $self->{$var};
    $self->{$var} = $val;
    shift @root;
  }
  shift @root if @root eq "--";

  push @root, "." unless @root;

  # Recurse into directories that are specified on the command-line, but no further.
  if (0==$self->{recursive}) {
    my @expanded;
    for my $dir (@root) {
      push @expanded, $dir;
      if (opendir DIR, $dir) {
	push @expanded, map {"$dir/$_"} sort readdir DIR;
	closedir DIR;
      }
    }
    @root = @expanded;
  }

  $self->{pending} = \@root;
  return $self;
}

# Return the absolute path of the top of the Git repository, or false if we're not in a Git repository
sub git_toplevel {
    my $toplevel = `git rev-parse --show-toplevel 2>/dev/null`;
    chomp $toplevel;
    return $toplevel;
}

# Return a mapping from filename to SHA1 for all known files if we're inside a git repo.
sub git_files {
    my %retval;
    open GIT, "git ls-tree -r --full-tree HEAD |" or return;
    local($_);
    while (<GIT>) {
	chomp;
	my($mode,$type,$sha1,$name) = split /\s+/, $_, 4;
	next unless defined $name;
	$retval{$name} = $sha1;
    }
    close GIT;
    return \%retval;
}


# Return true if the given file or directory (with path) is third-party software.
sub is_3rdparty {
  local($_) = @_;
  return 1 if m(/alt-mpi-headers/mpich-([\d\.]+)(p\d)?(/|$)); # in projects/compass/src/util/MPIAbstraction
  return 1 if m(/LANL_POP/netcdf-4\.(\d+)\.(\d+)(/|$)); # in tests/RunTests/FortranTests
  return 1 if m(/LANL_POP/pop-distro(/|$));             # in tests/RunTests/FortranTests
  return 1 if m(/3rdPartyLibraries(/|$));
  return 0;
}

# Return true if the given file or directory (with path) is machine-generated code.
sub is_generated {
  my $self = shift;
  local($_) = @_;
  if (my $gitdir = $self->{gitdir}) {
    return 0 if -d $_;
    my($filename) = abs_path($_) =~ m($gitdir/(.*));
    return 1 unless exists $self->{gitfiles}{$filename};
  }

  return 1 if m(/projects/compass/tools/compass/buildCheckers\.C$);
  return 1 if m(/projects/compass/tools/compassVerifier/buildCheckers\.C$);
  return 1 if m(/projects/compass/tools/sampleCompassSubset/buildCheckers\.C$);
  return 1 if m(/src/frontend/SageIII/ompparser\.h$);
  return 1 if m(/src/frontend/SageIII/string\.[Ch]$);
  return 1 if m(/src/roseIndependentSupport/dot2gml/parseDotGrammar\.h$);
  return 1 if m(/\.#); # Emacs temporary file
  return 1 if m(~$); # Emacs backup file
  return 0;
}

# Return true if the given directory (with path) is the ROSE install directory.
sub is_install {
  return 0 unless -d $_[0] && $ENV{prefix} ne "";
  local($_)  = abs_path(@_);
  my $prefix = abs_path($ENV{'prefix'});
  return 1 if $prefix eq $_;
  return 0;
}

# Return the next name, or undef when we reach the end.
sub next_name {
  my($self) = @_;
  my $retval = shift @{$self->{pending}};
  return $retval unless defined $retval;
  if ((!$self->{build}      && -d "$retval/include-staging") ||
      (!$self->{edg}        && $retval =~ /\/EDG(_[\d\.]+)?$/ && -d $retval) ||
      (!$self->{thirdparty} && is_3rdparty($retval)) ||
      (!$self->{generated}  && $self->is_generated($retval)) ||
      (!$self->{install}    && is_install($retval)) ||
      ($retval =~ /\/libltdl$/ && -d $retval) || # generated by $ROSE_SRC/build" script, we have no control over its contents
      ($retval =~ /\/\.(git|svn)$/ && -d $retval) || # no need to ever descend into Git or Subversion meta data
      ($retval =~ /~$/      && ! -d $retval) ||      # editor backup files
      ($retval =~ /\/\.#/)                           # emacs autosave files
     ) {
    return $self->next_name; # skip this name, return the next one
  } elsif ($self->{recursive}>0 && opendir DIR, $retval) {
    # Change 'unshift' to 'push' to get a breadth-first search
    unshift @{$self->{pending}}, map {"$retval/$_"} grep {!/^\.\.?$/} sort readdir DIR;
    close DIR;
  }
  return $retval;
}

# Return next name, skipping over directories
sub next_file {
  my($self) = @_;
  while (1) {
    my $retval = $self->next_name;
    return $retval unless -d $retval;
  }
}

# Return the next directory, skipping over non-directories
sub next_dir {
  my($self) = @_;
  while (1) {
    my $retval = $self->next_name;
    return unless defined $retval;
    return $retval if -d $retval;
  }
}

sub all {
  my($self,$code) = @_;
  my(@retval,$entry);
  push @retval, $entry while defined($entry=&{$code});
  return @retval;
}

# Returns all names
sub all_names {
  my($self) = @_;
  return $self->all(sub {$self->next_name});
}

# Return all files (non-directories)
sub all_files {
  my($self) = @_;
  return $self->all(sub {$self->next_file});
}

# Return all directories
sub all_dirs {
  my($self) = @_;
  return $self->all(sub {$self->next_dir});
}

1;

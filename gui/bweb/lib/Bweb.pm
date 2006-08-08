################################################################
use strict;

=head1 LICENSE

    Copyright (C) 2006 Eric Bollengier
        All rights reserved.

    This program is free software; you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation; either version 2 of the License, or
    any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this program; if not, write to the Free Software
    Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA

=head1 VERSION

    $Id$

=cut

package Bweb::Gui;

=head1 PACKAGE

    Bweb::Gui - Base package for all Bweb object

=head2 DESCRIPTION

    This package define base fonction like new, display, etc..

=cut

use HTML::Template;
our $template_dir='/usr/share/bweb/tpl';


=head1 FUNCTION

    new - creation a of new Bweb object

=head2 DESCRIPTION

    This function take an hash of argument and place them
    on bless ref

    IE : $obj = new Obj(name => 'test', age => '10');

         $obj->{name} eq 'test' and $obj->{age} eq 10

=cut

sub new
{
    my ($class, %arg) = @_;
    my $self = bless {
	name => undef,
    }, $class;

    map { $self->{lc($_)} = $arg{$_} } keys %arg ;

    return $self;
}

sub debug
{
    my ($self, $what) = @_;

    if ($self->{debug}) {
	if (ref $what) {
	    print "<pre>" . Data::Dumper::Dumper($what) . "</pre>";
	} else {
	    print "<pre>$what</pre>";
	}
    }
}

=head1 FUNCTION

    error - display an error to the user

=head2 DESCRIPTION

    this function set $self->{error} with arg, display a message with
    error.tpl and return 0

=head2 EXAMPLE

    unless (...) {
        return $self->error("Can't use this file");
    }

=cut

sub error
{
    my ($self, $what) = @_;
    $self->{error} = $what;
    $self->display($self, 'error.tpl');
    return 0;
}

=head1 FUNCTION

    display - display an html page with HTML::Template

=head2 DESCRIPTION

    this function is use to render all html codes. it takes an
    ref hash as arg in which all param are usable in template.

    it will use global template_dir to search the template file.

    hash keys are not sensitive. See HTML::Template for more
    explanations about the hash ref. (it's can be quiet hard to understand) 

=head2 EXAMPLE

    $ref = { name => 'me', age => 26 };
    $self->display($ref, "people.tpl");

=cut

sub display
{
    my ($self, $hash, $tpl) = @_ ;
    
    my $template = HTML::Template->new(filename => $tpl,
				       path =>[$template_dir],
				       die_on_bad_params => 0,
				       case_sensitive => 0);

    foreach my $var (qw/limit offset/) {

	unless ($hash->{$var}) {
	    my $value = CGI::param($var) || '';

	    if ($value =~ /^(\d+)$/) {
		$template->param($var, $1) ;
	    }
	}
    }

    $template->param('thisurl', CGI::url(-relative => 1, -query=>1));
    $template->param('loginname', CGI::remote_user());

    $template->param($hash);
    print $template->output();
}
1;

################################################################

package Bweb::Config;

use base q/Bweb::Gui/;

=head1 PACKAGE
    
    Bweb::Config - read, write, display, modify configuration

=head2 DESCRIPTION

    this package is used for manage configuration

=head2 USAGE

    $conf = new Bweb::Config(config_file => '/path/to/conf');
    $conf->load();

    $conf->edit();

    $conf->save();

=cut

use CGI;

=head1 PACKAGE VARIABLE

    %k_re - hash of all acceptable option.

=head2 DESCRIPTION

    this variable permit to check all option with a regexp.

=cut

our %k_re = ( dbi      => qr/^(dbi:(Pg|mysql):(?:\w+=[\w\d\.-]+;?)+)$/i,
	      user     => qr/^([\w\d\.-]+)$/i,
	      password => qr/^(.*)$/i,
	      template_dir => qr!^([/\w\d\.-]+)$!,
	      debug    => qr/^(on)?$/,
	      email_media => qr/^([\w\d\.-]+@[\d\w\.-]+)$/,
	      graph_font  => qr!^([/\w\d\.-]+.ttf)$!,
	      bconsole    => qr!^(.+)?$!,
	      syslog_file => qr!^(.+)?$!,
	      log_dir     => qr!^(.+)?$!,
	      );

=head1 FUNCTION

    load - load config_file

=head2 DESCRIPTION

    this function load the specified config_file.

=cut

sub load
{
    my ($self) = @_ ;

    unless (open(FP, $self->{config_file}))
    {
	return $self->error("$self->{config_file} : $!");
    }

    while (my $line = <FP>) 
    {
	chomp($line);
	my ($k, $v) = split(/\s*=\s*/, $line, 2);
	$self->{$k} = $v;
    }

    close(FP);
    return 1;
}

=head1 FUNCTION

    save - save the current configuration to config_file

=cut

sub save
{
    my ($self) = @_ ;

    unless (open(FP, ">$self->{config_file}"))
    {
	return $self->error("$self->{config_file} : $!");
    }
    
    foreach my $k (keys %$self)
    {
	next unless (exists $k_re{$k}) ;
	print FP "$k = $self->{$k}\n";
    }

    close(FP);       
    return 1;
}

=head1 FUNCTIONS
    
    edit, view, modify - html form ouput

=cut

sub edit
{
    my ($self) = @_ ;

    $self->display($self, "config_edit.tpl");
}

sub view
{
    my ($self) = @_ ;

    $self->display($self, "config_view.tpl");    
}

sub modify
{
    my ($self) = @_;
    
    $self->{error} = '';
    $self->{debug} = 0;

    foreach my $k (CGI::param())
    {
	next unless (exists $k_re{$k}) ;
	my $val = CGI::param($k);
	if ($val =~ $k_re{$k}) {
	    $self->{$k} = $1;
	} else {
	    $self->{error} .= "bad parameter : $k = [$val]";
	}
    }

    $self->display($self, "config_view.tpl");

    if ($self->{error}) {	# an error as occured
	$self->display($self, 'error.tpl');
    } else {
	$self->save();
    }
}

1;

################################################################

package Bweb::Client;

use base q/Bweb::Gui/;

=head1 PACKAGE
    
    Bweb::Client - Bacula FD

=head2 DESCRIPTION

    this package is use to do all Client operations like, parse status etc...

=head2 USAGE

    $client = new Bweb::Client(name => 'zog-fd');
    $client->status();            # do a 'status client=zog-fd'

=cut

=head1 FUNCTION

    display_running_job - Html display of a running job

=head2 DESCRIPTION

    this function is used to display information about a current job

=cut

sub display_running_job
{
    my ($self, $conf, $jobid) = @_ ;

    my $status = $self->status($conf);

    if ($jobid) {
	if ($status->{$jobid}) {
	    $self->display($status->{$jobid}, "client_job_status.tpl");
	}
    } else {
	for my $id (keys %$status) {
	    $self->display($status->{$id}, "client_job_status.tpl");
	}
    }
}

=head1 FUNCTION

    $client = new Bweb::Client(name => 'plume-fd');
                               
    $client->status($bweb);

=head2 DESCRIPTION

    dirty hack to parse "status client=xxx-fd"

=head2 INPUT

   JobId 105 Job Full_plume.2006-06-06_17.22.23 is running.
       Backup Job started: 06-jun-06 17:22
       Files=8,971 Bytes=194,484,132 Bytes/sec=7,480,158
       Files Examined=10,697
       Processing file: /home/eric/.openoffice.org2/user/config/standard.sod
       SDReadSeqNo=5 fd=5
   
=head2 OUTPUT

    $VAR1 = { 105 => {
        	JobName => Full_plume.2006-06-06_17.22.23,
        	JobId => 105,
        	Files => 8,971,
        	Bytes => 194,484,132,
        	...
              },
	      ...
    };

=cut

sub status
{
    my ($self, $conf) = @_ ;

    if (defined $self->{cur_jobs}) {
	return $self->{cur_jobs} ;
    }

    my $arg = {};
    my $b = new Bconsole(pref => $conf);
    my $ret = $b->send_cmd("st client=$self->{name}");
    my @param;
    my $jobid;

    for my $r (split(/\n/, $ret)) {
	chomp($r);
	$r =~ s/(^\s+|\s+$)//g;
	if ($r =~ /JobId (\d+) Job (\S+)/) {
	    if ($jobid) {
		$arg->{$jobid} = { @param, JobId => $jobid } ;
	    }

	    $jobid = $1;
	    @param = ( JobName => $2 );

	} elsif ($r =~ /=.+=/) {
	    push @param, split(/\s+|\s*=\s*/, $r) ;

	} elsif ($r =~ /=/) {	# one per line
	    push @param, split(/\s*=\s*/, $r) ;

	} elsif ($r =~ /:/) {	# one per line
	    push @param, split(/\s*:\s*/, $r, 2) ;
	}
    }

    if ($jobid and @param) {
	$arg->{$jobid} = { @param,
			   JobId => $jobid, 
			   Client => $self->{name},
		       } ;
    }

    $self->{cur_jobs} = $arg ;

    return $arg;
}
1;

################################################################

package Bweb::Autochanger;

use base q/Bweb::Gui/;

=head1 PACKAGE
    
    Bweb::Autochanger - Object to manage Autochanger

=head2 DESCRIPTION

    this package will parse the mtx output and manage drives.

=head2 USAGE

    $auto = new Bweb::Autochanger(precmd => 'sudo');
    or
    $auto = new Bweb::Autochanger(precmd => 'ssh root@robot');
                                  
    $auto->status();

    $auto->slot_is_full(10);
    $auto->transfer(10, 11);

=cut

# TODO : get autochanger definition from config/dump file
my %ach_list ;

sub get
{
    my ($name, $bweb) = @_;
    my $a = new Bweb::Autochanger(debug => $bweb->{debug}, 
				  bweb => $bweb,
				  name => 'SDLT-1-2',
				  precmd => 'sudo',
				  drive_name => ['SDLT-1', 'SDLT-2'],
				  );
    return $a;
}

sub new
{
    my ($class, %arg) = @_;

    my $self = bless {
	name  => '',    # autochanger name
	label => {},    # where are volume { label1 => 40, label2 => drive0 }
	drive => [],	# drive use [ 'media1', 'empty', ..]
	slot  => [],	# slot use [ undef, 'empty', 'empty', ..] no slot 0
	io    => [],    # io slot number list [ 41, 42, 43...]
	info  => {slot => 0,	# informations (slot, drive, io)
	          io   => 0,
	          drive=> 0,
	         },
	mtxcmd => '/usr/sbin/mtx',
	debug => 0,
	device => '/dev/changer',
	precmd => '',	# ssh command
	bweb => undef,	# link to bacula web object (use for display) 
    } ;

    map { $self->{lc($_)} = $arg{$_} } keys %arg ;

    return $self;
}

=head1 FUNCTION

    status - parse the output of mtx status

=head2 DESCRIPTION

    this function will launch mtx status and parse the output. it will
    give a perlish view of the autochanger content.

    it uses ssh if the autochanger is on a other host.

=cut

sub status
{
    my ($self) = @_;
    my @out = `$self->{precmd} $self->{mtxcmd} -f $self->{device} status` ;

    # TODO : reset all infos
    $self->{info}->{drive} = 0;
    $self->{info}->{slot}  = 0;
    $self->{info}->{io}    = 0;

    #my @out = `cat /home/eric/travail/brestore/plume/mtx` ;

#
#  Storage Changer /dev/changer:2 Drives, 45 Slots ( 5 Import/Export )
#Data Transfer Element 0:Full (Storage Element 1 Loaded):VolumeTag = 000000
#Data Transfer Element 1:Empty
#      Storage Element 1:Empty
#      Storage Element 2:Full :VolumeTag=000002
#      Storage Element 3:Empty
#      Storage Element 4:Full :VolumeTag=000004
#      Storage Element 5:Full :VolumeTag=000001
#      Storage Element 6:Full :VolumeTag=000003
#      Storage Element 7:Empty
#      Storage Element 41 IMPORT/EXPORT:Empty
#      Storage Element 41 IMPORT/EXPORT:Full :VolumeTag=000002
#

    for my $l (@out) {

        #          Storage Element 7:Empty
        #          Storage Element 2:Full :VolumeTag=000002
	if ($l =~ /Storage Element (\d+):(Empty|Full)(\s+:VolumeTag=([\w\d]+))?/){

	    if ($2 eq 'Empty') {
		$self->set_empty_slot($1);
	    } else {
		$self->set_slot($1, $4);
	    }

	} elsif ($l =~ /Data Transfer.+(\d+):(Full|Empty)(\s+.Storage Element (\d+) Loaded.(:VolumeTag = ([\w\d]+))?)?/) {

	    if ($2 eq 'Empty') {
		$self->set_empty_drive($1);
	    } else {
		$self->set_drive($1, $4, $6);
	    }

	} elsif ($l =~ /Storage Element (\d+).+IMPORT\/EXPORT:(Empty|Full)( :VolumeTag=([\d\w]+))?/) 
	{
	    if ($2 eq 'Empty') {
		$self->set_empty_io($1);
	    } else {
		$self->set_io($1, $4);
	    }

#       Storage Changer /dev/changer:2 Drives, 30 Slots ( 1 Import/Export )

	} elsif ($l =~ /Storage Changer .+:(\d+) Drives, (\d+) Slots/) {
	    $self->{info}->{drive} = $1;
	    $self->{info}->{slot} = $2;
	    if ($l =~ /(\d+)\s+Import/) {
		$self->{info}->{io} = $1 ;
	    } else {
		$self->{info}->{io} = 0;
	    }
	} 
    }

    $self->debug($self) ;
}

sub is_slot_loaded
{
    my ($self, $slot) = @_;

    # no barcodes
    if ($self->{slot}->[$slot] eq 'loaded') {
	return 1;
    } 

    my $label = $self->{slot}->[$slot] ;

    return $self->is_media_loaded($label);
}

sub unload
{
    my ($self, $drive, $slot) = @_;

    return 0 if (not defined $drive or $self->{drive}->[$drive] eq 'empty') ;
    return 0 if     ($self->slot_is_full($slot)) ;

    my $out = `$self->{precmd} $self->{mtxcmd} -f $self->{device} unload $slot $drive 2>&1`;
    
    if ($? == 0) {
	my $content = $self->get_slot($slot);
	print "content = $content<br/> $drive => $slot<br/>";
	$self->set_empty_drive($drive);
	$self->set_slot($slot, $content);
	return 1;
    } else {
	$self->{error} = $out;
	return 0;
    }
}

# TODO: load/unload have to use mtx script from bacula
sub load
{
    my ($self, $drive, $slot) = @_;

    return 0 if (not defined $drive or $self->{drive}->[$drive] ne 'empty') ;
    return 0 unless ($self->slot_is_full($slot)) ;

    print "Loading drive $drive with slot $slot<br/>\n";
    my $out = `$self->{precmd} $self->{mtxcmd} -f $self->{device} load $slot $drive 2>&1`;
    
    if ($? == 0) {
	my $content = $self->get_slot($slot);
	print "content = $content<br/> $slot => $drive<br/>";
	$self->set_drive($drive, $slot, $content);
	return 1;
    } else {
	$self->{error} = $out;
	print $out;
	return 0;
    }
}

sub is_media_loaded
{
    my ($self, $media) = @_;

    unless ($self->{label}->{$media}) {
	return 0;
    }

    if ($self->{label}->{$media} =~ /drive\d+/) {
	return 1;
    }

    return 0;
}

sub have_io
{
    my ($self) = @_;
    return (defined $self->{info}->{io} and $self->{info}->{io} > 0);
}

sub set_io
{
    my ($self, $slot, $tag) = @_;
    $self->{slot}->[$slot] = $tag || 'full';
    push @{ $self->{io} }, $slot;

    if ($tag) {
	$self->{label}->{$tag} = $slot;
    } 
}

sub set_empty_io
{
    my ($self, $slot) = @_;

    push @{ $self->{io} }, $slot;

    unless ($self->{slot}->[$slot]) {       # can be loaded (parse before) 
	$self->{slot}->[$slot] = 'empty';
    }
}

sub get_slot
{
    my ($self, $slot) = @_;
    return $self->{slot}->[$slot];
}

sub set_slot
{
    my ($self, $slot, $tag) = @_;
    $self->{slot}->[$slot] = $tag || 'full';

    if ($tag) {
	$self->{label}->{$tag} = $slot;
    }
}

sub set_empty_slot
{
    my ($self, $slot) = @_;

    unless ($self->{slot}->[$slot]) {       # can be loaded (parse before) 
	$self->{slot}->[$slot] = 'empty';
    }
}

sub set_empty_drive
{
    my ($self, $drive) = @_;
    $self->{drive}->[$drive] = 'empty';
}

sub set_drive
{
    my ($self, $drive, $slot, $tag) = @_;
    $self->{drive}->[$drive] = $tag || $slot;

    $self->{slot}->[$slot] = $tag || 'loaded';

    if ($tag) {
	$self->{label}->{$tag} = "drive$drive";
    }
}

sub slot_is_full
{
    my ($self, $slot) = @_;
    
    # slot don't exists => full
    if (not defined $self->{slot}->[$slot]) {
	return 0 ;
    }

    if ($self->{slot}->[$slot] eq 'empty') {
	return 0;
    }
    return 1;			# vol, full, loaded
}

sub slot_get_first_free
{
    my ($self) = @_;
    for (my $slot=1; $slot < $self->{info}->{slot}; $slot++) {
	return $slot unless ($self->slot_is_full($slot));
    }
}

sub io_get_first_free
{
    my ($self) = @_;
    
    foreach my $slot (@{ $self->{io} }) {
	return $slot unless ($self->slot_is_full($slot));	
    }
    return 0;
}

sub get_media_slot
{
    my ($self, $media) = @_;

    return $self->{label}->{$media} ;    
}

sub have_media
{
    my ($self, $media) = @_;

    return defined $self->{label}->{$media} ;    
}

sub send_to_io
{
    my ($self, $slot) = @_;

    unless ($self->slot_is_full($slot)) {
	print "Autochanger $self->{name} slot $slot is empty\n";
	return 1;		# ok
    }

    # first, eject it
    if ($self->is_slot_loaded($slot)) {
	# bconsole->umount
	# self->eject
	print "Autochanger $self->{name} $slot is currently in use\n";
	return 0;
    }

    # autochanger must have I/O
    unless ($self->have_io()) {
	print "Autochanger $self->{name} don't have I/O, you can take media yourself\n";
	return 0;
    }

    my $dst = $self->io_get_first_free();

    unless ($dst) {
	print "Autochanger $self->{name} you must empty I/O first\n";
    }

    $self->transfer($slot, $dst);
}

sub transfer
{
    my ($self, $src, $dst) = @_ ;
    print "$self->{precmd} $self->{mtxcmd} -f $self->{device} transfer $src $dst\n";
    my $out = `$self->{precmd} $self->{mtxcmd} -f $self->{device} transfer $src $dst 2>&1`;
    
    if ($? == 0) {
	my $content = $self->get_slot($src);
	print "content = $content<br/> $src => $dst<br/>";
	$self->{slot}->[$src] = 'empty';
	$self->set_slot($dst, $content);
	return 1;
    } else {
	$self->{error} = $out;
	return 0;
    }
}

# TODO : do a tapeinfo request to get informations
sub tapeinfo
{
    my ($self) = @_;
}

sub clear_io
{
    my ($self) = @_;

    for my $slot (@{$self->{io}})
    {
	if ($self->is_slot_loaded($slot)) {
	    print "$slot is currently loaded\n";
	    next;
	}

	if ($self->slot_is_full($slot))
	{
	    my $free = $self->slot_get_first_free() ;
	    print "want to move $slot to $free\n";

	    if ($free) {
		$self->transfer($slot, $free) || print "$self->{error}\n";
		
	    } else {
		$self->{error} = "E : Can't find free slot";
	    }
	}
    }
}

# TODO : this is with mtx status output,
# we can do an other function from bacula view (with StorageId)
sub display_content
{
    my ($self) = @_;
    my $bweb = $self->{bweb};

    # $self->{label} => ('vol1', 'vol2', 'vol3', ..);
    my $media_list = $bweb->dbh_join( keys %{ $self->{label} });

    my $query="
SELECT Media.VolumeName  AS volumename,
       Media.VolStatus   AS volstatus,
       Media.LastWritten AS lastwritten,
       Media.VolBytes    AS volbytes,
       Media.MediaType   AS mediatype,
       Media.Slot        AS slot,
       Media.InChanger   AS inchanger,
       Pool.Name         AS name,
       $bweb->{sql}->{FROM_UNIXTIME}(
          $bweb->{sql}->{UNIX_TIMESTAMP}(Media.LastWritten) 
        + $bweb->{sql}->{TO_SEC}(Media.VolRetention)
       ) AS expire
FROM Media 
 INNER JOIN Pool USING (PoolId) 

WHERE Media.VolumeName IN ($media_list)
";

    my $all = $bweb->dbh_selectall_hashref($query, 'volumename') ;

    # TODO : verify slot and bacula slot
    my $param = [];
    my @to_update;

    for (my $slot=1; $slot <= $self->{info}->{slot} ; $slot++) {

	if ($self->slot_is_full($slot)) {

	    my $vol = $self->{slot}->[$slot];
	    if (defined $all->{$vol}) {    # TODO : autochanger without barcodes 

		my $bslot = $all->{$vol}->{slot} ;
		my $inchanger = $all->{$vol}->{inchanger};

		# if bacula slot or inchanger flag is bad, we display a message
		if ($bslot != $slot or !$inchanger) {
		    push @to_update, $slot;
		}
		
		$all->{$vol}->{realslot} = $slot;
		$all->{$vol}->{volbytes} = Bweb::human_size($all->{$vol}->{volbytes}) ;
		
		push @{ $param }, $all->{$vol};

	    } else {		# empty or no label
		push @{ $param }, {realslot => $slot,
				   volstatus => 'Unknow',
				   volumename => $self->{slot}->[$slot]} ;
	    }
	} else {		# empty
	    push @{ $param }, {realslot => $slot, volumename => 'empty'} ;
	}
    }

    my $i=0; my $drives = [] ;
    foreach my $d (@{ $self->{drive} }) {
	$drives->[$i] = { index => $i,
			  load  => $self->{drive}->[$i],
			  name  => $self->{drive_name}->[$i],
		      };
	$i++;
    }

    $bweb->display({ Name   => $self->{name},
		     nb_drive => $self->{info}->{drive},
		     nb_io => $self->{info}->{io},
		     Drives => $drives,
		     Slots  => $param,
		     Update => scalar(@to_update) },
		   'ach_content.tpl');

}

1;


################################################################

package Bweb;

use base q/Bweb::Gui/;

=head1 PACKAGE

    Bweb - main Bweb package

=head2

    this package is use to compute and display informations

=cut

use DBI;
use POSIX qw/strftime/;

our $bpath="/usr/local/bacula";
our $bconsole="$bpath/sbin/bconsole -c $bpath/etc/bconsole.conf";

our $cur_id=0;

=head1 VARIABLE

    %sql_func - hash to make query mysql/postgresql compliant

=cut

our %sql_func = ( 
		  Pg => { 
		      UNIX_TIMESTAMP => '',
		      FROM_UNIXTIME => '',
		      TO_SEC => " interval '1 second' * ",
		      SEC_TO_INT => "SEC_TO_INT",
		      SEC_TO_TIME => '',
		  },
		  mysql => {
		      UNIX_TIMESTAMP => 'UNIX_TIMESTAMP',
		      FROM_UNIXTIME => 'FROM_UNIXTIME',
		      SEC_TO_INT => '',
		      TO_SEC => '',
		      SEC_TO_TIME => 'SEC_TO_TIME',
		  },
		 );

sub dbh_selectall_arrayref
{
    my ($self, $query) = @_;
    $self->connect_db();
    $self->debug($query);
    return $self->{dbh}->selectall_arrayref($query);
}

sub dbh_join
{
    my ($self, @what) = @_;
    return join(',', $self->dbh_quote(@what)) ;
}

sub dbh_quote
{
    my ($self, @what) = @_;

    $self->connect_db();
    if (wantarray) {
	return map { $self->{dbh}->quote($_) } @what;
    } else {
	return $self->{dbh}->quote($what[0]) ;
    }
}

sub dbh_do
{
    my ($self, $query) = @_ ; 
    $self->connect_db();
    $self->debug($query);
    return $self->{dbh}->do($query);
}

sub dbh_selectall_hashref
{
    my ($self, $query, $join) = @_;
    
    $self->connect_db();
    $self->debug($query);
    return $self->{dbh}->selectall_hashref($query, $join) ;
}

sub dbh_selectrow_hashref
{
    my ($self, $query) = @_;
    
    $self->connect_db();
    $self->debug($query);
    return $self->{dbh}->selectrow_hashref($query) ;
}

# display Mb/Gb/Kb
sub human_size
{
    my @unit = qw(b Kb Mb Gb Tb);
    my $val = shift || 0;
    my $i=0;
    my $format = '%i %s';
    while ($val / 1024 > 1) {
	$i++;
	$val /= 1024;
    }
    $format = ($i>0)?'%0.1f %s':'%i %s';
    return sprintf($format, $val, $unit[$i]);
}

# display Day, Hour, Year
sub human_sec
{
    use integer;

    my $val = shift;
    $val /= 60;			# sec -> min

    if ($val / 60 <= 1) {
	return "$val mins";
    } 

    $val /= 60;			# min -> hour
    if ($val / 24 <= 1) {
	return "$val hours";
    } 

    $val /= 24;			# hour -> day
    if ($val / 365 < 2) {
	return "$val days";
    } 

    $val /= 365 ;		# day -> year

    return "$val years";   
}

# get Day, Hour, Year
sub from_human_sec
{
    use integer;

    my $val = shift;
    unless ($val =~ /^\s*(\d+)\s*(\w)\w*\s*$/) {
	return 0;
    }

    my %times = ( m   => 60,
		  h   => 60*60,
		  d   => 60*60*24,
		  m   => 60*60*24*31,
		  y   => 60*60*24*365,
		  );
    my $mult = $times{$2} || 0;

    return $1 * $mult;   
}


sub connect_db
{
    my ($self) = @_;

    unless ($self->{dbh}) {
	$self->{dbh} = DBI->connect($self->{info}->{dbi}, 
				    $self->{info}->{user},
				    $self->{info}->{password});

	print "Can't connect to your database, see error log\n"
	    unless ($self->{dbh});

	$self->{dbh}->{FetchHashKeyName} = 'NAME_lc';
    }
}

sub new
{
    my ($class, %arg) = @_;
    my $self = bless { 
	dbh => undef,		# connect_db();
	info => {
	    dbi   => 'DBI:Pg:database=bacula;host=127.0.0.1',
	    user  => 'bacula',
	    password => 'test', 
	},
    } ;

    map { $self->{lc($_)} = $arg{$_} } keys %arg ;

    if ($self->{info}->{dbi} =~ /DBI:(\w+):/i) {
	$self->{sql} = $sql_func{$1};
    }

    $self->{debug} = $self->{info}->{debug};
    $Bweb::Gui::template_dir = $self->{info}->{template_dir};

    return $self;
}

sub display_begin
{
    my ($self) = @_;
    $self->display($self->{info}, "begin.tpl");
}

sub display_end
{
    my ($self) = @_;
    $self->display($self->{info}, "end.tpl");
}

sub display_clients
{
    my ($self) = @_;

    my $query = "
SELECT Name   AS name,
       Uname  AS uname,
       AutoPrune AS autoprune,
       FileRetention AS fileretention,
       JobRetention  AS jobretention

FROM Client
";

    my $all = $self->dbh_selectall_hashref($query, 'name') ;

    foreach (values %$all) {
	$_->{fileretention} = human_sec($_->{fileretention});
	$_->{jobretention} = human_sec($_->{jobretention});
    }

    my $arg = { ID => $cur_id++,
		clients => [ values %$all] };

    $self->display($arg, "client_list.tpl") ;
}

sub get_limit
{
    my ($self, %arg) = @_;

    my $limit = '';
    my $label = '';

    if ($arg{age}) {
	$limit = 
  "AND $self->{sql}->{UNIX_TIMESTAMP}(EndTime) 
         > 
       ( $self->{sql}->{UNIX_TIMESTAMP}(NOW()) 
         - 
         $self->{sql}->{TO_SEC}($arg{age})
       )" ;

	$label = "last " . human_sec($arg{age});
    }

    if ($arg{order}) {
	$limit .= " ORDER BY $arg{order} ";
    }

    if ($arg{limit}) {
	$limit .= " LIMIT $arg{limit} ";
	$label .= " limited to $arg{limit}";
    }

    if ($arg{offset}) {
	$limit .= " OFFSET $arg{offset} ";
	$label .= " with $arg{offset} offset ";
    }

    unless ($label) {
	$label = 'no filter';
    }

    return ($limit, $label);
}

=head1 FUNCTION

    $bweb->get_form(...) - Get useful stuff

=head2 DESCRIPTION

    This function get and check parameters against regexp.
    
    If word begin with 'q', the return will be quoted or join quoted
    if it's end with 's'.
    

=head2 EXAMPLE

    $bweb->get_form('jobid', 'qclient', 'qpools') ;

    { jobid    => 12,
      qclient  => 'plume-fd',
      qpools   => "'plume-fd', 'test-fd', '...'",
    }

=cut

sub get_form
{
    my ($self, @what) = @_;
    my %what = map { $_ => 1 } @what;
    my %ret;

    my %opt_i = (
		 limit  => 100,
		 cost   =>  10,
		 offset =>   0,
		 width  => 640,
		 height => 480,
		 jobid  =>   0,
		 slot   =>   0,
		 drive  =>   undef,
		 priority => 10,
		 age    => 60*60*24*7,
		 days   => 1,
		 );

    my %opt_s = (		# default to ''
		 ach    => 1,
		 status => 1,
                 client => 1,
		 level  => 1,
		 pool   => 1,
		 media  => 1,
                 ach    => 1,
                 jobtype=> 1,
		 );

    foreach my $i (@what) {
	if (exists $opt_i{$i}) {# integer param
	    my $value = CGI::param($i) || $opt_i{$i} ;
	    if ($value =~ /^(\d+)$/) {
		$ret{$i} = $1;
	    }
	} elsif ($opt_s{$i}) {	# simple string param
	    my $value = CGI::param($i) || '';
	    if ($value =~ /^([\w\d\.-]+)$/) {
		$ret{$i} = $1;
	    }
	} elsif ($i =~ /^j(\w+)s$/) { # quote join args
	    my @value = CGI::param($1) ;
	    if (@value) {
		$ret{$i} = $self->dbh_join(@value) ;
	    }

	} elsif ($i =~ /^q(\w+[^s])$/) { # 'arg1'
	    my $value = CGI::param($1) ;
	    if ($value) {
		$ret{$i} = $self->dbh_quote($value);
	    }

	} elsif ($i =~ /^q(\w+)s$/) { #[ 'arg1', 'arg2']
	    $ret{$i} = [ map { { name => $self->dbh_quote($_) } } 
			          CGI::param($1) ];
	}
    }

    if ($what{slots}) {
	foreach my $s (CGI::param('slot')) {
	    if ($s =~ /^(\d+)$/) {
		push @{$ret{slots}}, $s;
	    }
	}
    }

    if ($what{db_clients}) {
	my $query = "
SELECT Client.Name as clientname
FROM Client
";

	my $clients = $self->dbh_selectall_hashref($query, 'clientname');
	$ret{db_clients} = [sort {$a->{clientname} cmp $b->{clientname} } 
			      values %$clients] ;
    }

    if ($what{db_mediatypes}) {
	my $query = "
SELECT MediaType as mediatype
FROM MediaType
";

	my $medias = $self->dbh_selectall_hashref($query, 'mediatype');
	$ret{db_mediatypes} = [sort {$a->{mediatype} cmp $b->{mediatype} } 
			          values %$medias] ;
    }

    if ($what{db_locations}) {
	my $query = "
SELECT Location as location, Cost as cost FROM Location
";
	my $loc = $self->dbh_selectall_hashref($query, 'location');
	$ret{db_locations} = [ sort { $a->{location} 
				      cmp 
				      $b->{location} 
				  } values %$loc ];
    }

    if ($what{db_pools}) {
	my $query = "SELECT Name as name FROM Pool";

	my $all = $self->dbh_selectall_hashref($query, 'name') ;
	$ret{db_pools} = [ sort { $a->{name} cmp $b->{name} } values %$all ];
    }

    if ($what{db_filesets}) {
	my $query = "
SELECT FileSet.FileSet AS fileset 
FROM FileSet
";

	my $filesets = $self->dbh_selectall_hashref($query, 'fileset');

	$ret{db_filesets} = [sort {lc($a->{fileset}) cmp lc($b->{fileset}) } 
			       values %$filesets] ;

    }

    return \%ret;
}

sub display_graph
{
    my ($self) = @_;

    my $fields = $self->get_form(qw/age level status clients filesets 
				   db_clients limit db_filesets width height
				   qclients qfilesets/);
				

    my $url = CGI::url(-full => 0,
		       -base => 0,
		       -query => 1);
    $url =~ s/^.+?\?//;	# http://path/to/bweb.pl?arg => arg

    my $type = CGI::param('graph') || '';
    if ($type =~ /^(\w+)$/) {
	$fields->{graph} = $1;
    }

    my $gtype = CGI::param('gtype') || '';
    if ($gtype =~ /^(\w+)$/) {
	$fields->{gtype} = $1;
    } 

# this organisation is to keep user choice between 2 click
# TODO : fileset and client selection doesn't work

    $self->display({
	url => $url,
	%$fields,
    }, "graph.tpl")

}

sub display_client_job
{
    my ($self, %arg) = @_ ;

    $arg{order} = ' Job.JobId DESC ';
    my ($limit, $label) = $self->get_limit(%arg);

    my $clientname = $self->dbh_quote($arg{clientname});

    my $query="
SELECT DISTINCT Job.JobId       AS jobid,
		Job.Name        AS jobname,
                FileSet.FileSet AS fileset,
                Level           AS level,
                StartTime       AS starttime,
                JobFiles        AS jobfiles, 
                JobBytes        AS jobbytes,
                JobStatus       AS jobstatus,
		JobErrors	AS joberrors

 FROM Client,Job,FileSet
 WHERE Client.Name=$clientname
 AND Client.ClientId=Job.ClientId
 AND Job.FileSetId=FileSet.FileSetId
 $limit
";

    my $all = $self->dbh_selectall_hashref($query, 'jobid') ;

    foreach (values %$all) {
	$_->{jobbytes} = human_size($_->{jobbytes}) ;
    }

    $self->display({ clientname => $arg{clientname},
		     Filter => $label,
	             ID => $cur_id++,
		     Jobs => [ values %$all ],
		   },
		   "display_client_job.tpl") ;
}

sub get_selected_media_location
{
    my ($self) = @_ ;

    my $medias = $self->get_form('jmedias');

    unless ($medias->{jmedias}) {
	return undef;
    }

    my $query = "
SELECT Media.VolumeName AS volumename, Location.Location AS location
FROM Media LEFT JOIN Location ON (Media.LocationId = Location.LocationId)
WHERE Media.VolumeName IN ($medias->{jmedias})
";

    my $all = $self->dbh_selectall_hashref($query, 'volumename') ;
  
    # { 'vol1' => { [volumename => 'vol1', location => 'ici'],
    #               ..
    #             }
    # }
    return $all;
}

sub move_media
{
    my ($self) = @_ ;

    my $medias = $self->get_selected_media_location();

    unless ($medias) {
	return ;
    }
    
    my $elt = $self->get_form('db_locations');

    $self->display({ ID => $cur_id++,
		     %$elt,	# db_locations
		     medias => [ 
            sort { $a->{volumename} cmp $b->{volumename} } values %$medias
			       ],
		     },
		   "move_media.tpl");
}

sub help_extern
{
    my ($self) = @_ ;

    my $elt = $self->get_form(qw/db_pools db_mediatypes db_locations/) ;
    $self->debug($elt);
    $self->display($elt, "help_extern.tpl");
}

sub help_extern_compute
{
    my ($self) = @_;

    my $number = CGI::param('limit') || '' ;
    unless ($number =~ /^(\d+)$/) {
	return $self->error("Bad arg number : $number ");
    }

    my ($sql, undef) = $self->get_param('pools', 
					'locations', 'mediatypes');

    my $query = "
SELECT Media.VolumeName  AS volumename,
       Media.VolStatus   AS volstatus,
       Media.LastWritten AS lastwritten,
       Media.MediaType   AS mediatype,
       Media.VolMounts   AS volmounts,
       Pool.Name         AS name,
       Media.Recycle     AS recycle,
       $self->{sql}->{FROM_UNIXTIME}(
          $self->{sql}->{UNIX_TIMESTAMP}(Media.LastWritten) 
        + $self->{sql}->{TO_SEC}(Media.VolRetention)
       ) AS expire
FROM Media 
 INNER JOIN Pool     ON (Pool.PoolId = Media.PoolId)
 LEFT  JOIN Location ON (Media.LocationId = Location.LocationId)

WHERE Media.InChanger = 1
  AND Media.VolStatus IN ('Disabled', 'Error', 'Full')
  $sql
ORDER BY expire DESC, recycle, Media.VolMounts DESC
LIMIT $number
" ;
    
    my $all = $self->dbh_selectall_hashref($query, 'volumename') ;

    $self->display({ Medias => [ values %$all ] },
		   "help_extern_compute.tpl");
}

sub help_intern
{
    my ($self) = @_ ;

    my $param = $self->get_form(qw/db_locations db_pools db_mediatypes/) ;
    $self->display($param, "help_intern.tpl");
}

sub help_intern_compute
{
    my ($self) = @_;

    my $number = CGI::param('limit') || '' ;
    unless ($number =~ /^(\d+)$/) {
	return $self->error("Bad arg number : $number ");
    }

    my ($sql, undef) = $self->get_param('pools', 'locations', 'mediatypes');

    if (CGI::param('expired')) {
	$sql = "
AND (    $self->{sql}->{UNIX_TIMESTAMP}(Media.LastWritten) 
       + $self->{sql}->{TO_SEC}(Media.VolRetention)
    ) < NOW()
 " . $sql ;
    }

    my $query = "
SELECT Media.VolumeName  AS volumename,
       Media.VolStatus   AS volstatus,
       Media.LastWritten AS lastwritten,
       Media.MediaType   AS mediatype,
       Media.VolMounts   AS volmounts,
       Pool.Name         AS name,
       $self->{sql}->{FROM_UNIXTIME}(
          $self->{sql}->{UNIX_TIMESTAMP}(Media.LastWritten) 
        + $self->{sql}->{TO_SEC}(Media.VolRetention)
       ) AS expire
FROM Media 
 INNER JOIN Pool ON (Pool.PoolId = Media.PoolId) 
 LEFT  JOIN Location ON (Location.LocationId = Media.LocationId)

WHERE Media.InChanger <> 1
  AND Media.VolStatus IN ('Purged', 'Full', 'Append')
  AND Media.Recycle = 1
  $sql
ORDER BY Media.VolUseDuration DESC, Media.VolMounts ASC, expire ASC 
LIMIT $number
" ;
    
    my $all = $self->dbh_selectall_hashref($query, 'volumename') ;

    $self->display({ Medias => [ values %$all ] },
		   "help_intern_compute.tpl");

}

sub display_general
{
    my ($self, %arg) = @_ ;

    my ($limit, $label) = $self->get_limit(%arg);

    my $query = "
SELECT 
    (SELECT count(Pool.PoolId)   FROM Pool)   AS nb_pool, 
    (SELECT count(Media.MediaId) FROM Media)  AS nb_media, 
    (SELECT count(Job.JobId)     FROM Job)    AS nb_job,
    (SELECT sum(VolBytes)        FROM Media)  AS nb_bytes,
    (SELECT count(Job.JobId)     
      FROM Job
      WHERE Job.JobStatus IN ('E','e','f','A')
      $limit
    )					      AS nb_err,
    (SELECT count(Client.ClientId) FROM Client) AS nb_client
";

    my $row = $self->dbh_selectrow_hashref($query) ;

    $row->{nb_bytes} = human_size($row->{nb_bytes});

    $row->{db_size} = '???';
    $row->{label} = $label;

    $self->display($row, "general.tpl");
}

sub get_param
{
    my ($self, @what) = @_ ;
    my %elt = map { $_ => 1 } @what;
    my %ret;

    my $limit = '';

    if ($elt{clients}) {
	my @clients = CGI::param('client');
	if (@clients) {
	    $ret{clients} = \@clients;
	    my $str = $self->dbh_join(@clients);
	    $limit .= "AND Client.Name IN ($str) ";
	}
    }

    if ($elt{filesets}) {
	my @filesets = CGI::param('fileset');
	if (@filesets) {
	    $ret{filesets} = \@filesets;
	    my $str = $self->dbh_join(@filesets);
	    $limit .= "AND FileSet.FileSet IN ($str) ";
	}
    }

    if ($elt{mediatypes}) {
	my @medias = CGI::param('mediatype');
	if (@medias) {
	    $ret{mediatypes} = \@medias;
	    my $str = $self->dbh_join(@medias);
	    $limit .= "AND Media.MediaType IN ($str) ";
	}
    }

    if ($elt{client}) {
	my $client = CGI::param('client');
	$ret{client} = $client;
	$client = $self->dbh_join($client);
	$limit .= "AND Client.Name = $client ";
    }

    if ($elt{level}) {
	my $level = CGI::param('level') || '';
	if ($level =~ /^(\w)$/) {
	    $ret{level} = $1;
	    $limit .= "AND Job.Level = '$1' ";
	}
    }

    if ($elt{jobid}) {
	my $jobid = CGI::param('jobid') || '';

	if ($jobid =~ /^(\d+)$/) {
	    $ret{jobid} = $1;
	    $limit .= "AND Job.JobId = '$1' ";
	}
    }

    if ($elt{status}) {
	my $status = CGI::param('status') || '';
	if ($status =~ /^(\w)$/) {
	    $ret{status} = $1;
	    $limit .= "AND Job.JobStatus = '$1' ";
	}
    }

    if ($elt{locations}) {
	my @location = CGI::param('location') ;
	if (@location) {
	    $ret{locations} = \@location;	    
	    my $str = $self->dbh_join(@location);
	    $limit .= "AND Location.Location IN ($str) ";
	}
    }

    if ($elt{pools}) {
	my @pool = CGI::param('pool') ;
	if (@pool) {
	    $ret{pools} = \@pool; 
	    my $str = $self->dbh_join(@pool);
	    $limit .= "AND Pool.Name IN ($str) ";
	}
    }

    if ($elt{location}) {
	my $location = CGI::param('location') || '';
	if ($location) {
	    $ret{location} = $location;
	    $location = $self->dbh_quote($location);
	    $limit .= "AND Location.Location = $location ";
	}
    }

    if ($elt{pool}) {
	my $pool = CGI::param('pool') || '';
	if ($pool) {
	    $ret{pool} = $pool;
	    $pool = $self->dbh_quote($pool);
	    $limit .= "AND Pool.Name = $pool ";
	}
    }

    if ($elt{jobtype}) {
	my $jobtype = CGI::param('jobtype') || '';
	if ($jobtype =~ /^(\w)$/) {
	    $ret{jobtype} = $1;
	    $limit .= "AND Job.Type = '$1' ";
	}
    }

    return ($limit, %ret);
}

=head1

    get last backup

SELECT DISTINCT Job.JobId       AS jobid,
                Client.Name     AS client,
                FileSet.FileSet AS fileset,
		Job.Name        AS jobname,
                Level           AS level,
                StartTime       AS starttime,
                JobFiles        AS jobfiles, 
                JobBytes        AS jobbytes,
                VolumeName      AS volumename,
		JobStatus       AS jobstatus,
                JobErrors	AS joberrors

 FROM Client,Job,JobMedia,Media,FileSet
 WHERE Client.ClientId=Job.ClientId
   AND Job.FileSetId=FileSet.FileSetId
   AND JobMedia.JobId=Job.JobId 
   AND JobMedia.MediaId=Media.MediaId
 $limit

=cut 

sub display_job
{
    my ($self, %arg) = @_ ;

    $arg{order} = ' Job.JobId DESC ';

    my ($limit, $label) = $self->get_limit(%arg);
    my ($where, undef) = $self->get_param('clients',
					  'level',
					  'filesets',
					  'jobtype',
					  'jobid',
					  'status');

    my $query="
SELECT  Job.JobId       AS jobid,
        Client.Name     AS client,
        FileSet.FileSet AS fileset,
	Job.Name        AS jobname,
        Level           AS level,
        StartTime       AS starttime,
        Pool.Name       AS poolname,
        JobFiles        AS jobfiles, 
        JobBytes        AS jobbytes,
	JobStatus       AS jobstatus,
        JobErrors	AS joberrors

 FROM Client, 
      Job LEFT JOIN Pool     ON (Job.PoolId    = Pool.PoolId)
          LEFT JOIN FileSet  ON (Job.FileSetId = FileSet.FileSetId)
 WHERE Client.ClientId=Job.ClientId
 $where
 $limit
";

    my $all = $self->dbh_selectall_hashref($query, 'jobid') ;

    foreach (values %$all) {
	$_->{jobbytes} = human_size($_->{jobbytes}) ;
    }

    $self->display({ Filter => $label,
	             ID => $cur_id++,
		     Jobs => 
			   [ 
			     sort { $a->{jobid} <=>  $b->{jobid} } 
			                values %$all 
			     ],
		   },
		   "display_job.tpl");
}

# display job informations
sub display_job_zoom
{
    my ($self, $jobid) = @_ ;

    $jobid = $self->dbh_quote($jobid);
    
    my $query="
SELECT DISTINCT Job.JobId       AS jobid,
                Client.Name     AS client,
		Job.Name        AS jobname,
                FileSet.FileSet AS fileset,
                Level           AS level,
	        Pool.Name       AS poolname,
                StartTime       AS starttime,
                JobFiles        AS jobfiles, 
                JobBytes        AS jobbytes,
		JobStatus       AS jobstatus,
                $self->{sql}->{SEC_TO_TIME}(  $self->{sql}->{UNIX_TIMESTAMP}(EndTime)  
                                            - $self->{sql}->{UNIX_TIMESTAMP}(StartTime)) AS duration

 FROM Client,
      Job LEFT JOIN FileSet ON (Job.FileSetId = FileSet.FileSetId)
          LEFT JOIN Pool    ON (Job.PoolId    = Pool.PoolId)
 WHERE Client.ClientId=Job.ClientId
 AND Job.JobId = $jobid
";

    my $row = $self->dbh_selectrow_hashref($query) ;

    $row->{jobbytes} = human_size($row->{jobbytes}) ;

    # display all volumes associate with this job
    $query="
SELECT Media.VolumeName as volumename
FROM Job,Media,JobMedia
WHERE Job.JobId = $jobid
 AND JobMedia.JobId=Job.JobId 
 AND JobMedia.MediaId=Media.MediaId
";

    my $all = $self->dbh_selectall_hashref($query, 'volumename');

    $row->{volumes} = [ values %$all ] ;

    $self->display($row, "display_job_zoom.tpl");
}

sub display_media
{
    my ($self) = @_ ;

    my ($where, %elt) = $self->get_param('pool',
					 'location');

    my $query="
SELECT Media.VolumeName AS volumename, 
       Media.VolBytes   AS volbytes,
       Media.VolStatus  AS volstatus,
       Media.MediaType  AS mediatype,
       Media.InChanger  AS online,
       Media.LastWritten AS lastwritten,
       Location.Location AS location,
       Pool.Name         AS poolname,
       $self->{sql}->{FROM_UNIXTIME}(
          $self->{sql}->{UNIX_TIMESTAMP}(Media.LastWritten) 
        + $self->{sql}->{TO_SEC}(Media.VolRetention)
       ) AS expire
FROM Pool, Media LEFT JOIN Location ON (Media.LocationId = Location.LocationId)
WHERE Media.PoolId=Pool.PoolId
$where
";

    my $all = $self->dbh_selectall_hashref($query, 'volumename') ;
    foreach (values %$all) {
	$_->{volbytes} = human_size($_->{volbytes}) ;
    }

    $self->display({ ID => $cur_id++,
		     Pool => $elt{pool},
		     Location => $elt{location},
		     Medias => [ values %$all ]
		   },
		   "display_media.tpl");
}

sub display_medias
{
    my ($self) = @_ ;

    my $pool = $self->get_form('db_pools');
    
    foreach my $name (@{ $pool->{db_pools} }) {
	CGI::param('pool', $name->{name});
	$self->display_media();
    }
}

sub display_media_zoom
{
    my ($self) = @_ ;

    my $medias = $self->get_form('jmedias');
    
    unless ($medias->{jmedias}) {
	return $self->error("Can't get media selection");
    }
    
    my $query="
SELECT InChanger     AS online,
       VolBytes      AS nb_bytes,
       VolumeName    AS volumename,
       VolStatus     AS volstatus,
       VolMounts     AS nb_mounts,
       Media.VolUseDuration   AS voluseduration,
       Media.MaxVolJobs AS maxvoljobs,
       Media.MaxVolFiles AS maxvolfiles,
       Media.MaxVolBytes AS maxvolbytes,
       VolErrors     AS nb_errors,
       Pool.Name     AS poolname,
       Location.Location AS location,
       Media.Recycle AS recycle,
       Media.VolRetention AS volretention,
       Media.LastWritten  AS lastwritten,
       $self->{sql}->{FROM_UNIXTIME}(
          $self->{sql}->{UNIX_TIMESTAMP}(Media.LastWritten) 
        + $self->{sql}->{TO_SEC}(Media.VolRetention)
       ) AS expire
 FROM Job,Pool,
      Media LEFT JOIN Location ON (Media.LocationId = Location.LocationId)
 WHERE Pool.PoolId = Media.PoolId
 AND VolumeName IN ($medias->{jmedias})
";

    my $all = $self->dbh_selectall_hashref($query, 'volumename') ;

    foreach my $media (values %$all) {
	$media->{nb_bytes} = human_size($media->{nb_bytes}) ;
	$media->{voluseduration} = human_sec($media->{voluseduration});
	$media->{volretention} = human_sec($media->{volretention});
	my $mq = $self->dbh_quote($media->{volumename});

	$query = "
SELECT DISTINCT Job.JobId AS jobid,
                Job.Name  AS name,
                Job.StartTime AS starttime,
		Job.Type  AS type,
                Job.Level AS level,
                Job.JobFiles AS files,
		Job.JobBytes AS bytes,
                Job.jobstatus AS status
 FROM Media,JobMedia,Job
 WHERE Media.VolumeName=$mq
 AND Media.MediaId=JobMedia.MediaId              
 AND JobMedia.JobId=Job.JobId
";

	my $jobs = $self->dbh_selectall_hashref($query, 'jobid') ;

	foreach (values %$jobs) {
	    $_->{bytes} = human_size($_->{bytes}) ;
	}

	$self->display({ jobs => [ values %$jobs ],
		         %$media },
		       "display_media_zoom.tpl");
    }
}

sub location_edit
{
    my ($self) = @_ ;

    my $loc = $self->get_form('qlocation');
    unless ($loc->{qlocation}) {
	return $self->error("Can't get location");
    }

    my $query = "
SELECT Location.Location AS location, 
       Location.Cost   AS cost,
       Location.Enabled AS enabled
FROM Location
WHERE Location.Location = $loc->{qlocation}
";

    my $row = $self->dbh_selectrow_hashref($query);

    $self->display({ ID => $cur_id++,
		     %$row }, "location_edit.tpl") ;

}

sub location_save
{
    my ($self) = @_ ;

    my $arg = $self->get_form(qw/qlocation qnewlocation cost/) ;
    unless ($arg->{qlocation}) {
	return $self->error("Can't get location");
    }    
    unless ($arg->{qnewlocation}) {
	return $self->error("Can't get new location name");
    }
    unless ($arg->{cost}) {
	return $self->error("Can't get new cost");
    }

    my $enabled = CGI::param('enabled') || '';
    $enabled = $enabled?1:0;

    my $query = "
UPDATE Location SET Cost     = $arg->{cost}, 
                    Location = $arg->{qnewlocation},
                    Enabled   = $enabled
WHERE Location.Location = $arg->{qlocation}
";

    $self->dbh_do($query);

    $self->display_location();
}

sub location_add
{
    my ($self) = @_ ;
    my $arg = $self->get_form(qw/qlocation cost/) ;

    unless ($arg->{qlocation}) {
	$self->display({}, "location_add.tpl");
	return 1;
    }
    unless ($arg->{cost}) {
	return $self->error("Can't get new cost");
    }

    my $enabled = CGI::param('enabled') || '';
    $enabled = $enabled?1:0;

    my $query = "
INSERT INTO Location (Location, Cost, Enabled) 
       VALUES ($arg->{qlocation}, $arg->{cost}, $enabled)
";

    $self->dbh_do($query);

    $self->display_location();
}

sub display_location
{
    my ($self) = @_ ;

    my $query = "
SELECT Location.Location AS location, 
       Location.Cost     AS cost,
       Location.Enabled  AS enabled,
       (SELECT count(Media.MediaId) 
         FROM Media 
        WHERE Media.LocationId = Location.LocationId
       ) AS volnum
FROM Location
";

    my $location = $self->dbh_selectall_hashref($query, 'location');

    $self->display({ ID => $cur_id++,
		     Locations => [ values %$location ] },
		   "display_location.tpl");
}

sub update_location
{
    my ($self) = @_ ;

    my $medias = $self->get_selected_media_location();
    unless ($medias) {
	return ;
    }

    my $arg = $self->get_form('db_locations', 'qnewlocation');

    $self->display({ email  => $self->{info}->{email_media},
		     %$arg,
                     medias => [ values %$medias ],
		   },
		   "update_location.tpl");
}

sub do_update_media
{
    my ($self) = @_ ;

    my $media = CGI::param('media');
    unless ($media) {
	return $self->error("Can't find media selection");
    }

    $media = $self->dbh_quote($media);

    my $update = '';

    my $volstatus = CGI::param('volstatus') || ''; 
    $volstatus = $self->dbh_quote($volstatus); # is checked by db
    $update .= " VolStatus=$volstatus, ";
    
    my $inchanger = CGI::param('inchanger') || '';
    if ($inchanger) {
	$update .= " InChanger=1, " ;
	my $slot = CGI::param('slot') || '';
	if ($slot =~ /^(\d+)$/) {
	    $update .= " Slot=$1, ";
	} else {
	    $update .= " Slot=0, ";
	}
    } else {
	$update = " Slot=0, InChanger=0, ";
    }

    my $pool = CGI::param('pool') || '';
    $pool = $self->dbh_quote($pool); # is checked by db
    $update .= " PoolId=(SELECT PoolId FROM Pool WHERE Name=$pool), ";

    my $volretention = CGI::param('volretention') || '';
    $volretention = from_human_sec($volretention);
    unless ($volretention) {
	return $self->error("Can't get volume retention");
    }

    $update .= " VolRetention = $volretention, ";

    my $loc = CGI::param('location') || '';
    $loc = $self->dbh_quote($loc); # is checked by db
    $update .= " LocationId=(SELECT LocationId FROM Location WHERE Location=$loc), ";

    my $usedu = CGI::param('voluseduration') || '0';
    $usedu = from_human_sec($usedu);
    $update .= " VolUseDuration=$usedu, ";

    my $maxj = CGI::param('maxvoljobs') || '0';
    unless ($maxj =~ /^(\d+)$/) {
	return $self->error("Can't get max jobs");
    }
    $update .= " MaxVolJobs=$1, " ;

    my $maxf = CGI::param('maxvolfiles') || '0';
    unless ($maxj =~ /^(\d+)$/) {
	return $self->error("Can't get max files");
    }
    $update .= " MaxVolFiles=$1, " ;
   
    my $maxb = CGI::param('maxvolbytes') || '0';
    unless ($maxb =~ /^(\d+)$/) {
	return $self->error("Can't get max bytes");
    }
    $update .= " MaxVolBytes=$1 " ;
    
    my $row=$self->dbh_do("UPDATE Media SET $update WHERE VolumeName=$media");
    
    if ($row) {
	print "Update Ok\n";
	$self->update_media();
    }
}

sub update_media
{
    my ($self) = @_ ;

    my $media = $self->get_form('qmedia');

    unless ($media->{qmedia}) {
	return $self->error("Can't get media");
    }

    my $query = "
SELECT Media.Slot         AS slot,
       Pool.Name          AS poolname,
       Media.VolStatus    AS volstatus,
       Media.InChanger    AS inchanger,
       Location.Location  AS location,
       Media.VolumeName   AS volumename,
       Media.MaxVolBytes  AS maxvolbytes,
       Media.MaxVolJobs   AS maxvoljobs,
       Media.MaxVolFiles  AS maxvolfiles,
       Media.VolUseDuration AS voluseduration,
       Media.VolRetention AS volretention

FROM Media INNER JOIN Pool ON (Media.PoolId = Pool.PoolId)
           LEFT  JOIN Location ON (Media.LocationId = Location.LocationId)

WHERE Media.VolumeName = $media->{qmedia}
";

    my $row = $self->dbh_selectrow_hashref($query);
    $row->{volretention} = human_sec($row->{volretention});
    $row->{voluseduration} = human_sec($row->{voluseduration});

    my $elt = $self->get_form(qw/db_pools db_locations/);

    $self->display({
	%$elt,
        %$row,
    },
		   "update_media.tpl");
}

sub save_location
{
    my ($self) = @_ ;

    my $medias = $self->get_selected_media();

    unless ($medias) {
	return 0;
    }
    
    my $loc = $self->get_form('qnewlocation');
    unless ($loc->{qnewlocation}) {
	return $self->error("Can't get new location");
    }

    my $query = "
 UPDATE Media 
     SET LocationId = (SELECT LocationId 
                       FROM Location 
                       WHERE Location = $loc->{qnewlocation}) 
     WHERE Media.VolumeName IN ($medias)
";

    my $nb = $self->dbh_do($query);

    print "$nb media updated";
}

sub change_location
{
    my ($self) = @_ ;

    my $medias = $self->get_selected_media_location();
    unless ($medias) {
	return $self->error("Can't get media selection");
    }
    my $newloc = CGI::param('newlocation');

    my $user = CGI::param('user') || 'unknow';
    my $comm = CGI::param('comment') || '';
    $comm = $self->dbh_quote("$user: $comm");

    my $query;

    foreach my $media (keys %$medias) {
	$query = "
INSERT LocationLog (Date, Comment, MediaId, LocationId, NewVolStatus)
 VALUES(
       NOW(), $comm, (SELECT MediaId FROM Media WHERE VolumeName = '$media'),
       (SELECT LocationId FROM Location WHERE Location = '$medias->{$media}->{location}'),
       (SELECT VolStatus FROM Media WHERE VolumeName = '$media')
      )
";
	
	$self->debug($query);
    }

    my $q = new CGI;
    $q->param('action', 'update_location');
    my $url = $q->url(-full => 1, -query=>1);

    $self->display({ email  => $self->{info}->{email_media},
		     url => $url,
		     newlocation => $newloc,
		     # [ { volumename => 'vol1' }, { volumename => 'vol2' },..]
		     medias => [ values %$medias ],
		   },
		   "change_location.tpl");

}

sub display_client_stats
{
    my ($self, %arg) = @_ ;

    my $client = $self->dbh_quote($arg{clientname});
    my ($limit, $label) = $self->get_limit(%arg);

    my $query = "
SELECT 
    count(Job.JobId)     AS nb_jobs,
    sum(Job.JobBytes)    AS nb_bytes,
    sum(Job.JobErrors)   AS nb_err,
    sum(Job.JobFiles)    AS nb_files,
    Client.Name          AS clientname
FROM Job INNER JOIN Client USING (ClientId)
WHERE 
    Client.Name = $client
    $limit 
GROUP BY Client.Name
";

    my $row = $self->dbh_selectrow_hashref($query);

    $row->{ID} = $cur_id++;
    $row->{label} = $label;
    $row->{nb_bytes}    = human_size($row->{nb_bytes}) ;

    $self->display($row, "display_client_stats.tpl");
}

# poolname can be undef
sub display_pool
{
    my ($self, $poolname) = @_ ;
    
# TODO : afficher les tailles et les dates

    my $query = "
SELECT Pool.Name     AS name, 
       Pool.Recycle  AS recycle,
       Pool.VolRetention AS volretention,
       Pool.VolUseDuration AS voluseduration,
       Pool.MaxVolJobs AS maxvoljobs,
       Pool.MaxVolFiles AS maxvolfiles,
       Pool.MaxVolBytes AS maxvolbytes, 
      (SELECT count(Media.MediaId) 
         FROM Media 
        WHERE Media.PoolId = Pool.PoolId
      ) AS volnum
 FROM Pool
";	

    my $all = $self->dbh_selectall_hashref($query, 'name') ;
    foreach (values %$all) {
	$_->{maxvolbytes}    = human_size($_->{maxvolbytes}) ;
	$_->{volretention}   = human_sec($_->{volretention}) ;
	$_->{voluseduration} = human_sec($_->{voluseduration}) ;
    }

    $self->display({ ID => $cur_id++,
		     Pools => [ values %$all ]},
		   "display_pool.tpl");
}

sub display_running_job
{
    my ($self) = @_;

    my $arg = $self->get_form('client', 'jobid');

    if (!$arg->{client} and $arg->{jobid}) {

	my $query = "
SELECT Client.Name AS name
FROM Job INNER JOIN Client USING (ClientId)
WHERE Job.JobId = $arg->{jobid}
";

	my $row = $self->dbh_selectrow_hashref($query);

	if ($row) {
	    $arg->{client} = $row->{name};
	    CGI::param('client', $arg->{client});
	}
    }

    if ($arg->{client}) {
	my $cli = new Bweb::Client(name => $arg->{client});
	$cli->display_running_job($self->{info}, $arg->{jobid});
	if ($arg->{jobid}) {
	    $self->get_job_log();
	}
    } else {
	$self->error("Can't get client or jobid");
    }
}

sub display_running_jobs
{
    my ($self, $display_action) = @_;
    
    my $query = "
SELECT Job.JobId AS jobid, 
       Job.Name  AS jobname,
       Job.Level     AS level,
       Job.StartTime AS starttime,
       Job.JobFiles  AS jobfiles,
       Job.JobBytes  AS jobbytes,
       Job.JobStatus AS jobstatus,
$self->{sql}->{SEC_TO_TIME}(  $self->{sql}->{UNIX_TIMESTAMP}(NOW())  
                            - $self->{sql}->{UNIX_TIMESTAMP}(StartTime)) 
         AS duration,
       Client.Name AS clientname
FROM Job INNER JOIN Client USING (ClientId) 
WHERE JobStatus IN ('C','R','B','e','D','F','S','m','M','s','j','c','d','t','p')
";	
    my $all = $self->dbh_selectall_hashref($query, 'jobid') ;
    
    $self->display({ ID => $cur_id++,
		     display_action => $display_action,
		     Jobs => [ values %$all ]},
		   "running_job.tpl") ;
}

sub eject_media
{
    my ($self) = @_;
    my $arg = $self->get_form('jmedias', 'slots', 'ach');

    unless ($arg->{jmedias}) {
	return $self->error("Can't get media selection");
    }
    
    my $query = "
SELECT Media.VolumeName  AS volumename,
       Storage.Name      AS storage,
       Location.Location AS location,
       Media.Slot        AS slot
FROM Media INNER JOIN Storage  ON (Media.StorageId  = Storage.StorageId)
           LEFT  JOIN Location ON (Media.LocationId = Location.LocationId)
WHERE Media.VolumeName IN ($arg->{jmedias})
  AND Media.InChanger = 1
";

    my $all = $self->dbh_selectall_hashref($query, 'volumename');

    my $a = Bweb::Autochanger::get('SDLT-1-2', $self);

    $a->status();
    foreach my $vol (values %$all) {
	print "eject $vol->{volumename} from $vol->{storage} : ";
	if ($a->send_to_io($vol->{slot})) {
	    print "ok</br>";
	} else {
	    print "err</br>";
	}
    }
}

sub restore
{
    my ($self) = @_;
    
    my $arg = $self->get_form('jobid', 'client');

    print CGI::header('text/brestore');
    print "jobid=$arg->{jobid}\n" if ($arg->{jobid});
    print "client=$arg->{client}\n" if ($arg->{client});
    print "\n";
}

# TODO : move this to Bweb::Autochanger ?
# TODO : make this internal to not eject tape ?
use Bconsole;

sub delete
{
    my ($self) = @_;
    my $arg = $self->get_form('jobid');

    my $b = new Bconsole(pref => $self->{info});

    if ($arg->{jobid}) {
	my $ret = $b->send_cmd("delete jobid=\"$arg->{jobid}\"");
	$self->display({
	    content => $b->send_cmd("delete jobid=\"$arg->{jobid}\""),
	    title => "Delete a job ",
	    name => "delete jobid=$arg->{jobid}",
	}, "command.tpl");	
    }
}

sub update_slots
{
    my ($self) = @_;

    my $ach = CGI::param('ach') ;
    unless ($ach =~ /^([\w\d\.-]+)$/) {
	return $self->error("Bad autochanger name");
    }

    my $b = new Bconsole(pref => $self->{info});
    print "<pre>" . $b->update_slots($ach) . "</pre>";
}

sub get_job_log
{
    my ($self) = @_;

    my $arg = $self->get_form('jobid');
    unless ($arg->{jobid}) {
	return $self->error("Can't get jobid");
    }

    my $t = CGI::param('time') || '';

    my $query = "
SELECT Job.Name as name, Client.Name as clientname
 FROM  Job INNER JOIN Client ON (Job.ClientId = Client.ClientId)
 WHERE JobId = $arg->{jobid}
";

    my $row = $self->dbh_selectrow_hashref($query);

    unless ($row) {
	return $self->error("Can't find $arg->{jobid} in catalog");
    }
    

    $query = "
SELECT Time AS time, LogText AS log
 FROM  Log
 WHERE JobId = $arg->{jobid}
";
    my $log = $self->dbh_selectall_arrayref($query);
    unless ($log) {
	return $self->error("Can't get log for jobid $arg->{jobid}");
    }

    if ($t) {
	# log contains \n
	$logtxt = join("", map { ($_->[0] . ' ' . $_->[1]) } @$log ) ; 
    } else {
	$logtxt = join("", map { $_->[1] } @$log ) ; 
    }
    
    $self->display({ lines=> $logtxt,
		     jobid => $arg->{jobid},
		     name  => $row->{name},
		     client => $row->{clientname},
		 }, 'display_log.tpl');
}


sub label_barcodes
{
    my ($self) = @_ ;

    my $arg = $self->get_form('ach', 'slots', 'drive');

    unless ($arg->{ach}) {
	return $self->error("Can't find autochanger name");
    }

    my $slots = '';
    if ($arg->{slots}) {
	$slots = join(",", @{ $arg->{slots} });
    }

    my $t = 60*scalar( @{ $arg->{slots} });
    my $b = new Bconsole(pref => $self->{info}, timeout => $t,log_stdout => 1);
    print "<h1>This command can take long time, be patient...</h1>";
    print "<pre>" ;
    $b->label_barcodes(storage => $arg->{ach},
		       drive => $arg->{drive},
		       pool  => 'Scratch',
		       slots => $slots) ;
    print "</pre>";
}

sub purge
{
    my ($self) = @_;

    my @volume = CGI::param('media');

    my $b = new Bconsole(pref => $self->{info}, timeout => 60);

    $self->display({
	content => $b->purge_volume(@volume),
	title => "Purge media",
	name => "purge volume=" . join(' volume=', @volume),
    }, "command.tpl");	
}

sub prune
{
    my ($self) = @_;

    my $b = new Bconsole(pref => $self->{info}, timeout => 60);

    my @volume = CGI::param('media');
    $self->display({
	content => $b->prune_volume(@volume),
	title => "Prune media",
	name => "prune volume=" . join(' volume=', @volume),
    }, "command.tpl");	
}

sub cancel_job
{
    my ($self) = @_;

    my $arg = $self->get_form('jobid');
    unless ($arg->{jobid}) {
	return $self->error('Bad jobid');
    }

    my $b = new Bconsole(pref => $self->{info});
    $self->display({
	content => $b->cancel($arg->{jobid}),
	title => "Cancel job",
	name => "cancel jobid=$arg->{jobid}",
    }, "command.tpl");	
}

sub director_show_sched
{
    my ($self) = @_ ;

    my $arg = $self->get_form('days');

    my $b = new Bconsole(pref => $self->{info}) ;
    
    my $ret = $b->director_get_sched( $arg->{days} );

    $self->display({
	id => $cur_id++,
	list => $ret,
    }, "scheduled_job.tpl");
}

sub enable_disable_job
{
    my ($self, $what) = @_ ;

    my $name = CGI::param('job') || '';
    unless ($name =~ /^[\w\d\.\-\s]+$/) {
	return $self->error("Can't find job name");
    }

    my $b = new Bconsole(pref => $self->{info}) ;

    my $cmd;
    if ($what) {
	$cmd = "enable";
    } else {
	$cmd = "disable";
    }

    $self->display({
	content => $b->send_cmd("$cmd job=\"$name\""),
	title => "$cmd $name",
	name => "$cmd job=\"$name\"",
    }, "command.tpl");	
}

sub run_job_select
{
    my ($self) = @_;
    $b = new Bconsole(pref => $self->{info});

    my $joblist = [ map { { name => $_ } } split(/\r\n/, $b->send_cmd(".job")) ];

    $self->display({ Jobs => $joblist }, "run_job.tpl");
}

sub run_parse_job
{
    my ($self, $ouput) = @_;

    my %arg;
    foreach my $l (split(/\r\n/, $ouput)) {
	if ($l =~ /(\w+): name=([\w\d\.\s-]+?)(\s+\w+=.+)?$/) {
	    $arg{$1} = $2;
	    $l = $3 
		if ($3) ;
	} 

	if (my @l = $l =~ /(\w+)=([\w\d*]+)/g) {
	    %arg = (%arg, @l);
	}
    }

    my %lowcase ;
    foreach my $k (keys %arg) {
	$lowcase{lc($k)} = $arg{$k} ;
    }

    return \%lowcase;
}

sub run_job_mod
{
    my ($self) = @_;
    $b = new Bconsole(pref => $self->{info});
    
    my $job = CGI::param('job') || '';

    my $info = $b->send_cmd("show job=\"$job\"");
    my $attr = $self->run_parse_job($info);
    
    my $jobs   = [ map {{ name => $_ }} split(/\r\n/, $b->send_cmd(".job")) ];

    my $pools  = [ map { { name => $_ } } split(/\r\n/, $b->send_cmd(".pool")) ];
    my $clients = [ map { { name => $_ } } split(/\r\n/, $b->send_cmd(".client")) ];
    my $filesets= [ map { { name => $_ } } split(/\r\n/, $b->send_cmd(".fileset")) ];
    my $storages= [ map { { name => $_ } } split(/\r\n/, $b->send_cmd(".storage")) ];

    $self->display({
	jobs     => $jobs,
	pools    => $pools,
	clients  => $clients,
	filesets => $filesets,
	storages => $storages,
	%$attr,
    }, "run_job_mod.tpl");
}

sub run_job
{
    my ($self) = @_;
    $b = new Bconsole(pref => $self->{info});
    
    my $jobs   = [ map {{ name => $_ }} split(/\r\n/, $b->send_cmd(".job")) ];

    $self->display({
	jobs     => $jobs,
    }, "run_job.tpl");
}

sub run_job_now
{
    my ($self) = @_;
    $b = new Bconsole(pref => $self->{info});
    
    # TODO: check input (don't use pool, level)

    my $arg = $self->get_form('pool', 'level', 'client', 'priority');
    my $job = CGI::param('job') || '';
    my $storage = CGI::param('storage') || '';

    my $jobid = $b->run(job => $job,
			client => $arg->{client},
			priority => $arg->{priority},
			level => $arg->{level},
			storage => $storage,
			pool => $arg->{pool},
			);

    print $jobid, $b->{error};    

    print "<br>You can follow job execution <a href='?action=dsp_cur_job;client=$arg->{client};jobid=$jobid'> here </a>";
}

1;

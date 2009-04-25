# $Id: Gtk.pm 2509 2009-03-27 20:02:21Z rcaputo $

# Gtk-Perl event loop bridge for POE::Kernel.

# Empty package to appease perl.
package POE::Loop::Gtk;

use strict;

# Include common signal handling.
use POE::Loop::PerlSignals;

use vars qw($VERSION);
$VERSION = do {my($r)=(q$Revision: 2509 $=~/(\d+)/);sprintf"1.%04d",$r};

=for poe_tests

sub skip_tests {
  return "Gtk needs a DISPLAY (set one today, okay?)" unless (
    defined $ENV{DISPLAY} and length $ENV{DISPLAY}
  );
  return "Gtk tests require the Gtk module" if do { eval "use Gtk"; $@ };
  return "Gtk init failed.  Is DISPLAY valid?" unless defined Gtk->init_check;
  return;
}

=cut

# Everything plugs into POE::Kernel.
package POE::Kernel;

use strict;

my $_watcher_timer;
my @fileno_watcher;
my $gtk_init_check;

#------------------------------------------------------------------------------
# Loop construction and destruction.

sub loop_initialize {
  my $self = shift;

  # Must Gnome->init() yourselves, as it takes parameters.
  unless (exists $INC{'Gnome.pm'}) {
    # Gtk can only be initialized once. 
    # So if we've initialized it already, skip the whole deal.
    unless($gtk_init_check) {
      $gtk_init_check++;

      my $res = Gtk->init_check();

      # Now check whether the init was ok.
      # undefined == icky; TRUE (whatever that means in gtk land) means Ok.
      if (defined $res) {
        Gtk->init();

      } else {
        POE::Kernel::_die "Gtk initialization failed. Chances are it couldn't connect to a display. Of course, Gtk doesn't put its error message anywhere I can find so we can't be more specific here.";
      }
    }
  }
}

sub loop_finalize {
  my $self = shift;

  foreach my $fd (0..$#fileno_watcher) {
    next unless defined $fileno_watcher[$fd];
    foreach my $mode (MODE_RD, MODE_WR, MODE_EX) {
      POE::Kernel::_warn(
        "Mode $mode watcher for fileno $fd is defined during loop finalize"
      ) if defined $fileno_watcher[$fd]->[$mode];
    }
  }

  $self->loop_ignore_all_signals();
}

#------------------------------------------------------------------------------
# Signal handler maintenance functions.

# This function sets us up a signal when whichever window is passed to
# it closes.
sub loop_attach_uidestroy {
  my ($self, $window) = @_;

  # Don't bother posting the signal if there are no sessions left.  I
  # think this is a bit of a kludge: the situation where a window
  # lasts longer than POE::Kernel should never occur.
  $window->signal_connect(
    delete_event => sub {
      if ($self->_data_ses_count()) {
        $self->_dispatch_event
          ( $self, $self,
            EN_SIGNAL, ET_SIGNAL, [ 'UIDESTROY' ],
            __FILE__, __LINE__, undef, time(), -__LINE__
          );
      }
      return 0;
    }
  );
}

#------------------------------------------------------------------------------
# Maintain time watchers.

sub loop_resume_time_watcher {
  my ($self, $next_time) = @_;
  $next_time -= time();
  $next_time *= 1000;
  $next_time = 0 if $next_time < 0;
  $_watcher_timer = Gtk->timeout_add($next_time, \&_loop_event_callback);
}

sub loop_reset_time_watcher {
  my ($self, $next_time) = @_;
  # Should always be defined, right?
  Gtk->timeout_remove($_watcher_timer);
  undef $_watcher_timer;
  $self->loop_resume_time_watcher($next_time);
}

sub _loop_resume_timer {
  Gtk->idle_remove($_watcher_timer);
  $poe_kernel->loop_resume_time_watcher($poe_kernel->get_next_event_time());
}

sub loop_pause_time_watcher {
  # does nothing
}

#------------------------------------------------------------------------------
# Maintain filehandle watchers.

sub loop_watch_filehandle {
  my ($self, $handle, $mode) = @_;
  my $fileno = fileno($handle);

  # Overwriting a pre-existing watcher?
  if (defined $fileno_watcher[$fileno]->[$mode]) {
    Gtk::Gdk->input_remove($fileno_watcher[$fileno]->[$mode]);
    undef $fileno_watcher[$fileno]->[$mode];
  }

  if (TRACE_FILES) {
    POE::Kernel::_warn "<fh> watching $handle in mode $mode";
  }

  # Register the new watcher.
  $fileno_watcher[$fileno]->[$mode] =
    Gtk::Gdk->input_add( $fileno,
                         ( ($mode == MODE_RD)
                           ? ( 'read',
                               \&_loop_select_read_callback
                             )
                           : ( ($mode == MODE_WR)
                               ? ( 'write',
                                   \&_loop_select_write_callback
                                 )
                               : ( 'exception',
                                   \&_loop_select_expedite_callback
                                 )
                             )
                         ),
                         $fileno
                       );
}

sub loop_ignore_filehandle {
  my ($self, $handle, $mode) = @_;
  my $fileno = fileno($handle);

  if (TRACE_FILES) {
    POE::Kernel::_warn "<fh> ignoring $handle in mode $mode";
  }

  # Don't bother removing a select if none was registered.
  if (defined $fileno_watcher[$fileno]->[$mode]) {
    Gtk::Gdk->input_remove($fileno_watcher[$fileno]->[$mode]);
    undef $fileno_watcher[$fileno]->[$mode];
  }
}

sub loop_pause_filehandle {
  my ($self, $handle, $mode) = @_;
  my $fileno = fileno($handle);

  if (TRACE_FILES) {
    POE::Kernel::_warn "<fh> pausing $handle in mode $mode";
  }

  Gtk::Gdk->input_remove($fileno_watcher[$fileno]->[$mode]);
  undef $fileno_watcher[$fileno]->[$mode];
}

sub loop_resume_filehandle {
  my ($self, $handle, $mode) = @_;
  my $fileno = fileno($handle);

  # Quietly ignore requests to resume unpaused handles.
  return 1 if defined $fileno_watcher[$fileno]->[$mode];

  if (TRACE_FILES) {
    POE::Kernel::_warn "<fh> resuming $handle in mode $mode";
  }

  $fileno_watcher[$fileno]->[$mode] =
    Gtk::Gdk->input_add( $fileno,
                         ( ($mode == MODE_RD)
                           ? ( 'read',
                               \&_loop_select_read_callback
                             )
                           : ( ($mode == MODE_WR)
                               ? ( 'write',
                                   \&_loop_select_write_callback
                                 )
                               : ( 'exception',
                                   \&_loop_select_expedite_callback
                                 )
                             )
                         ),
                         $fileno
                       );
}

### Callbacks.

# Event callback to dispatch pending events.

my $last_time = time();

sub _loop_event_callback {
  my $self = $poe_kernel;

  if (TRACE_STATISTICS) {
    # TODO - I'm pretty sure the startup time will count as an unfair
    # amount of idleness.
    #
    # TODO - Introducing many new time() syscalls.  Bleah.
    $self->_data_stat_add('idle_seconds', time() - $last_time);
  }

  $self->_data_ev_dispatch_due();
  $self->_test_if_kernel_is_idle();

  Gtk->timeout_remove($_watcher_timer);
  undef $_watcher_timer;

  # Register the next timeout if there are events left.
  if ($self->get_event_count()) {
    $_watcher_timer = Gtk->idle_add(\&_loop_resume_timer);
  }

  # And back to Gtk, so we're in idle mode.
  $last_time = time() if TRACE_STATISTICS;

  # Return false to stop.
  return 0;
}

# Filehandle callback to dispatch selects.
sub _loop_select_read_callback {
  my $self = $poe_kernel;
  my ($handle, $fileno, $hash) = @_;

  if (TRACE_FILES) {
    POE::Kernel::_warn "<fh> got read callback for $handle";
  }

  $self->_data_handle_enqueue_ready(MODE_RD, $fileno);
  $self->_test_if_kernel_is_idle();

  # Return false to stop... probably not with this one.
  return 0;
}

sub _loop_select_write_callback {
  my $self = $poe_kernel;
  my ($handle, $fileno, $hash) = @_;

  if (TRACE_FILES) {
    POE::Kernel::_warn "<fh> got write callback for $handle";
  }

  $self->_data_handle_enqueue_ready(MODE_WR, $fileno);
  $self->_test_if_kernel_is_idle();

  # Return false to stop... probably not with this one.
  return 0;
}

sub _loop_select_expedite_callback {
  my $self = $poe_kernel;
  my ($handle, $fileno, $hash) = @_;

  if (TRACE_FILES) {
    POE::Kernel::_warn "<fh> got expedite callback for $handle";
  }

  $self->_data_handle_enqueue_ready(MODE_EX, $fileno);
  $self->_test_if_kernel_is_idle();

  # Return false to stop... probably not with this one.
  return 0;
}

#------------------------------------------------------------------------------
# The event loop itself.

sub loop_do_timeslice {
  die "doing timeslices currently not supported in the Gtk loop";
}

sub loop_run {
  unless (defined $_watcher_timer) {
    $_watcher_timer = Gtk->idle_add(\&_loop_resume_timer);
  }
  Gtk->main;
}

sub loop_halt {
  Gtk->main_quit();
}

1;

__END__

=head1 NAME

POE::Loop::Gtk - a bridge that allows POE to be driven by Gtk

=head1 SYNOPSIS

See L<POE::Loop>.

=head1 DESCRIPTION

POE::Loop::Gtk implements the interface documented in L<POE::Loop>.
Therefore it has no documentation of its own.  Please see L<POE::Loop>
for more details.

=head1 SEE ALSO

L<POE>, L<POE::Loop>, L<Gtk>, L<POE::Loop::PerlSignals>

=head1 AUTHORS & LICENSING

Please see L<POE> for more information about authors, contributors,
and POE's licensing.

=cut

# rocco // vim: ts=2 sw=2 expandtab
# TODO - Edit.

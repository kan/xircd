# $Id: Signals.pm 2478 2009-03-01 18:55:04Z rcaputo $

# The data necessary to manage signals, and the accessors to get at
# that data in a sane fashion.

package POE::Resource::Signals;

use vars qw($VERSION);
$VERSION = do {my($r)=(q$Revision: 2478 $=~/(\d+)/);sprintf"1.%04d",$r};

# These methods are folded into POE::Kernel;
package POE::Kernel;

use strict;

use POSIX qw(:sys_wait_h);

### Map watched signal names to the sessions that are watching them
### and the events that must be delivered when they occur.

my %kr_signals;
#  ( $signal_name =>
#    { $session_reference => $event_name,
#      ...,
#    },
#    ...,
#  );

my %kr_sessions_to_signals;
#  ( $session =>
#    { $signal_name => $event_name,
#      ...,
#    },
#    ...,
#  );

my %kr_pids_to_events;
# { $pid =>
#   { $session =>
#     [ $blessed_session,   # PID_SESSION
#       $event_name,        # PID_EVENT
#     ]
#   }
# }

my %kr_sessions_to_pids;
# { $session => { $pid => 1 } }

sub PID_SESSION () { 0 }
sub PID_EVENT   () { 1 }

# Bookkeeping per dispatched signal.

use vars (
 '@kr_signaled_sessions',            # The sessions touched by a signal.
 '$kr_signal_total_handled',         # How many sessions handled a signal.
 '$kr_signal_type',                  # The type of signal being dispatched.
);

#my @kr_signaled_sessions;           # The sessions touched by a signal.
#my $kr_signal_total_handled;        # How many sessions handled a signal.
#my $kr_signal_type;                 # The type of signal being dispatched.

# A flag to tell whether we're currently polling for signals.
# Under USE_SIGCHLD, determines whether a SIGCHLD polling event has already been queued
my $polling_for_signals = 0;

# A flag determining whether there are child processes.
my $kr_child_procs = exists($INC{'Apache.pm'}) ? 0 : ( USE_SIGCHLD ? 0 : 1 );

# A list of special signal types.  Signals that aren't listed here are
# benign (they do not kill sessions at all).  "Terminal" signals are
# the ones that UNIX defaults to killing processes with.  Thus STOP is
# not terminal.

sub SIGTYPE_BENIGN      () { 0x00 }
sub SIGTYPE_TERMINAL    () { 0x01 }
sub SIGTYPE_NONMASKABLE () { 0x02 }

my %_signal_types = (
  QUIT => SIGTYPE_TERMINAL,
  INT  => SIGTYPE_TERMINAL,
  KILL => SIGTYPE_TERMINAL,
  TERM => SIGTYPE_TERMINAL,
  HUP  => SIGTYPE_TERMINAL,
  IDLE => SIGTYPE_TERMINAL,
  DIE  => SIGTYPE_TERMINAL,
  ZOMBIE    => SIGTYPE_NONMASKABLE,
  UIDESTROY => SIGTYPE_NONMASKABLE,
);

# Build a list of useful, real signals.  Nonexistent signals, and ones
# which are globally unhandled, usually cause segmentation faults if
# perl was poorly configured.  Some signals aren't available in some
# environments.

my %_safe_signals;

sub _data_sig_initialize {
  my $self = shift;

  # Initialize this to a true value so our waitpid() loop can run at
  # least once.  Starts false when running in an Apache handler so our
  # SIGCHLD hijinks don't interfere with the web server.
  $kr_child_procs = exists($INC{'Apache.pm'}) ? 0 : ( USE_SIGCHLD ? 0 : 1 );

  $poe_kernel->[KR_SIGNALS] = \%kr_signals;
  $poe_kernel->[KR_PIDS]    = \%kr_pids_to_events;

  # In case we're called multiple times.
  unless (keys %_safe_signals) {
    foreach my $signal (keys %SIG) {

      # Nonexistent signals, and ones which are globally unhandled.
      next if (
        $signal =~ /^
          ( NUM\d+
          |__[A-Z0-9]+__
          |ALL|CATCHALL|DEFER|HOLD|IGNORE|MAX|PAUSE
          |RTMIN|RTMAX|SETS
          |SEGV
          |
          )
        $/x
      );

      # Windows doesn't have a SIGBUS, but the debugger causes SIGBUS
      # to be entered into %SIG.  It's fatal to register its handler.
      next if $signal eq 'BUS' and RUNNING_IN_HELL;

      # Apache uses SIGCHLD and/or SIGCLD itself, so we can't.
      next if $signal =~ /^CH?LD$/ and exists $INC{'Apache.pm'};

      $_safe_signals{$signal} = 1;
    }

    # Reset some important signal handlers.  The rest remain
    # untouched.

    $self->loop_ignore_signal("CHLD") if exists $SIG{CHLD};
    $self->loop_ignore_signal("CLD")  if exists $SIG{CLD};
    $self->loop_ignore_signal("PIPE") if exists $SIG{PIPE};
  }
}

### Return signals that are safe to manipulate.

sub _data_sig_get_safe_signals {
  return keys %_safe_signals;
}

### End-run leak checking.

sub _data_sig_finalize {
  my $finalized_ok = 1;

  while (my ($sig, $sig_rec) = each(%kr_signals)) {
    $finalized_ok = 0;
    _warn "!!! Leaked signal $sig\n";
    while (my ($ses, $event) = each(%{$kr_signals{$sig}})) {
      _warn "!!!\t$ses = $event\n";
    }
  }

  while (my ($ses, $sig_rec) = each(%kr_sessions_to_signals)) {
    $finalized_ok = 0;
    _warn "!!! Leaked signal cross-reference: $ses\n";
    while (my ($sig, $event) = each(%{$kr_signals{$ses}})) {
      _warn "!!!\t$sig = $event\n";
    }
  }

  while (my ($ses, $pid_rec) = each(%kr_sessions_to_pids)) {
    $finalized_ok = 0;
    my @pids = keys %$pid_rec;
    _warn "!!! Leaked session to PID map: $ses -> (@pids)\n";
  }

  while (my ($pid, $ses_rec) = each(%kr_pids_to_events)) {
    $finalized_ok = 0;
    _warn "!!! Leaked PID to event map: $pid\n";
    while (my ($ses, $event_rec) = each %$ses_rec) {
      _warn "!!!\t$ses -> $event_rec->[PID_EVENT]\n";
    }
  }

  %_safe_signals = ();

  unless (RUNNING_IN_HELL) {
    local $!;
    local $?;
    until ((my $pid = waitpid( -1, 0 )) == -1) {
      _warn( "!!! Child process PID:$pid reaped: $!\n" ) if $pid;
      $finalized_ok = 0;
    }
  }

  return $finalized_ok;
}

### Add a signal to a session.

sub _data_sig_add {
  my ($self, $session, $signal, $event) = @_;

  $kr_sessions_to_signals{$session}->{$signal} = $event;
  $self->_data_sig_signal_watch($session, $signal);
  $kr_signals{$signal}->{$session} = $event;
}

sub _data_sig_signal_watch {
  my ($self, $session, $signal) = @_;

  # First session to watch the signal.
  # Ask the event loop to watch the signal.
  if (
    !exists($kr_signals{$signal}) and
    exists($_safe_signals{$signal}) and
    ($signal ne "CHLD" or !scalar(keys %kr_sessions_to_pids))
  ) {
    $self->loop_watch_signal($signal);
  }
}

sub _data_sig_signal_ignore {
  my ($self, $session, $signal) = @_;

  if (
    !exists($kr_signals{$signal}) and
    exists($_safe_signals{$signal}) and
    ($signal ne "CHLD" or !scalar(keys %kr_sessions_to_pids))
  ) {
    $self->loop_ignore_signal($signal);
  }
}

### Remove a signal from a session.

sub _data_sig_remove {
  my ($self, $session, $signal) = @_;

  delete $kr_sessions_to_signals{$session}->{$signal};
  delete $kr_sessions_to_signals{$session}
    unless keys(%{$kr_sessions_to_signals{$session}});

  delete $kr_signals{$signal}->{$session};

  # Last watcher for that signal.  Stop watching it internally.
  unless (keys %{$kr_signals{$signal}}) {
    delete $kr_signals{$signal};
    $self->_data_sig_signal_ignore($session, $signal);
  }
}

### Clear all the signals from a session.

# XXX - It's ok to clear signals from a session that doesn't exist.
# Usually it means that the signals are being cleared, but it might
# mean that the session really doesn't exist.  Should we care?

sub _data_sig_clear_session {
  my ($self, $session) = @_;

  if (exists $kr_sessions_to_signals{$session}) { # avoid autoviv
    foreach (keys %{$kr_sessions_to_signals{$session}}) {
      $self->_data_sig_remove($session, $_);
    }
  }

  if (exists $kr_sessions_to_pids{$session}) { # avoid autoviv
    foreach (keys %{$kr_sessions_to_pids{$session}}) {
      $self->_data_sig_pid_ignore($session, $_);
    }
  }
}

### Watch and ignore PIDs.

sub _data_sig_pid_watch {
  my ($self, $session, $pid, $event) = @_;

  $kr_pids_to_events{$pid}{$session} = [
    $session, # PID_SESSION
    $event,   # PID_EVENT
  ];

  $self->_data_sig_signal_watch($session, "CHLD");

  $kr_sessions_to_pids{$session}{$pid} = 1;
  $self->_data_ses_refcount_inc($session);
}

sub _data_sig_pid_ignore {
  my ($self, $session, $pid) = @_;

  # Remove PID to event mapping.

  delete $kr_pids_to_events{$pid}{$session};
  delete $kr_pids_to_events{$pid} unless (
    keys %{$kr_pids_to_events{$pid}}
  );

  # Remove session to PID mapping.

  delete $kr_sessions_to_pids{$session}{$pid};
  unless (keys %{$kr_sessions_to_pids{$session}}) {
    delete $kr_sessions_to_pids{$session};
    $self->_data_sig_signal_ignore($session, "CHLD");
  }

  $self->_data_ses_refcount_dec($session);
}

sub _data_sig_pids_ses {
  my ($self, $session) = @_;
  return 0 unless exists $kr_sessions_to_pids{$session};
  return scalar keys %{$kr_sessions_to_pids{$session}};
}

sub _data_sig_pids_is_ses_watching {
  my ($self, $session, $pid) = @_;
  return(
    exists($kr_sessions_to_pids{$session}) &&
    exists($kr_sessions_to_pids{$session}{$pid})
  );
}

### Return a signal's type, or SIGTYPE_BENIGN if it's not special.

sub _data_sig_type {
  my ($self, $signal) = @_;
  return $_signal_types{$signal} || SIGTYPE_BENIGN;
}

### Flag a signal as being handled by some session.

sub _data_sig_handled {
  my $self = shift;
  $kr_signal_total_handled++;
}

### Clear the structures associated with a signal's "handled" status.

sub _data_sig_reset_handled {
  my ($self, $signal) = @_;
  undef $kr_signal_total_handled;
  $kr_signal_type = $self->_data_sig_type($signal);
  undef @kr_signaled_sessions;
}

### Is the signal explicitly watched?

sub _data_sig_explicitly_watched {
  my ($self, $signal) = @_;
  return exists $kr_signals{$signal};
}

### Return the signals watched by a session and the events they
### generate.  TODO Used mainly for testing, but may also be useful
### for introspection.

sub _data_sig_watched_by_session {
  my ($self, $session) = @_;
  return %{$kr_sessions_to_signals{$session}};
}

### Which sessions are watching a signal?

sub _data_sig_watchers {
  my ($self, $signal) = @_;
  return %{$kr_signals{$signal}};
}

### Return the current signal's handled status.
### TODO Used for testing.

sub _data_sig_handled_status {
  return(
    $kr_signal_total_handled,
    $kr_signal_type,
    \@kr_signaled_sessions,
  );
}

### Determine if a given session is watching a signal.  This uses a
### two-step exists so that the longer one does not autovivify keys in
### the shorter one.

sub _data_sig_is_watched_by_session {
  my ($self, $signal, $session) = @_;
  return(
    exists($kr_signals{$signal}) &&
    exists($kr_signals{$signal}->{$session})
  );
}

### Destroy sessions touched by a nonmaskable signal or by an
### unhandled terminal signal.  Check for garbage-collection on
### sessions which aren't to be terminated.

sub _data_sig_free_terminated_sessions {
  my $self = shift;

  if (
    ($kr_signal_type & SIGTYPE_NONMASKABLE) or
    ($kr_signal_type & SIGTYPE_TERMINAL and !$kr_signal_total_handled)
  ) {
    foreach my $dead_session (@kr_signaled_sessions) {
      next unless $self->_data_ses_exists($dead_session);
      if (TRACE_SIGNALS) {
        _warn(
          "<sg> stopping signaled session ",
          $self->_data_alias_loggable($dead_session)
        );
      }

      $self->_data_ses_stop($dead_session);
    }
  }
  else {
    # TODO Implicit signal reaping.  This is deprecated behavior and
    # will eventually be removed.  See the commented out tests in
    # t/res/signals.t.
    #
    # Don't reap the parent if it's the kernel.  It still needs to be
    # a part of the system for finalization in certain cases.
    foreach my $touched_session (@kr_signaled_sessions) {
      next unless $self->_data_ses_exists($touched_session);
      next if $touched_session == $self;
      $self->_data_ses_collect_garbage($touched_session);
    }
  }

  # Erase @kr_signaled_sessions, or they will leak until the next
  # signal.
  undef @kr_signaled_sessions;
}

### A signal has touched a session.  Record this fact for later
### destruction tests.

sub _data_sig_touched_session {
  my ($self, $session) = @_;
  push @kr_signaled_sessions, $session;
}

# only used under !USE_SIGCHLD
sub _data_sig_begin_polling {
  my $self = shift;

  return if $polling_for_signals;
  $polling_for_signals = 1;

  $self->_data_sig_enqueue_poll_event();
  $self->_idle_queue_grow();
}

# only used under !USE_SIGCHLD
sub _data_sig_cease_polling {
  $polling_for_signals = 0;
}

sub _data_sig_enqueue_poll_event {
  my $self = shift;

  if ( USE_SIGCHLD ) {
    return if $polling_for_signals;
    $polling_for_signals = 1;

    $self->_data_ev_enqueue(
      $self, $self, EN_SCPOLL, ET_SCPOLL, [ ],
      __FILE__, __LINE__, undef, time(),
    );
  } else {
    return if $self->_data_ses_count() < 1;
    return unless $polling_for_signals;

    $self->_data_ev_enqueue(
      $self, $self, EN_SCPOLL, ET_SCPOLL, [ ],
      __FILE__, __LINE__, undef, time() + POE::Kernel::CHILD_POLLING_INTERVAL(),
    );
  }
}

sub _data_sig_handle_poll_event {
  my $self = shift;

  if ( USE_SIGCHLD ) {
    $polling_for_signals = undef;
  }

  if (TRACE_SIGNALS) {
    _warn("<sg> POE::Kernel is polling for signals at " . time() . (USE_SIGCHLD ? " due to SIGCHLD" : ""));
  }

  # Reap children for as long as waitpid(2) says something
  # interesting has happened.
  # TODO This has a possibility of an infinite loop, but so far it
  # hasn't hasn't happened.

  my $pid;
  while ($pid = waitpid(-1, WNOHANG)) {
    # waitpid(2) returned a process ID.  Emit an appropriate SIGCHLD
    # event and loop around again.

    if ((RUNNING_IN_HELL and $pid < -1) or ($pid > 0)) {
      if (RUNNING_IN_HELL or WIFEXITED($?) or WIFSIGNALED($?)) {

        if (TRACE_SIGNALS) {
          _warn("<sg> POE::Kernel detected SIGCHLD (pid=$pid; exit=$?)");
        }

        # Check for explicit SIGCHLD watchers, and enqueue explicit
        # events for them.

        if (exists $kr_pids_to_events{$pid}) {
          my @sessions_to_clear;
          while (my ($ses_key, $ses_rec) = each %{$kr_pids_to_events{$pid}}) {
            $self->_data_ev_enqueue(
              $ses_rec->[PID_SESSION], $self, $ses_rec->[PID_EVENT], ET_SIGCLD,
              [ 'CHLD', $pid, $? ],
              __FILE__, __LINE__, undef, time(),
            );
            push @sessions_to_clear, $ses_rec->[PID_SESSION];
          }
          $self->_data_sig_pid_ignore($_, $pid) foreach @sessions_to_clear;
        }

        # Kick off a SIGCHLD cascade.
        $self->_data_ev_enqueue(
          $self, $self, EN_SIGNAL, ET_SIGNAL, [ 'CHLD', $pid, $? ],
          __FILE__, __LINE__, undef, time(),
        );
      }
      elsif (TRACE_SIGNALS) {
        _warn("<sg> POE::Kernel detected strange exit (pid=$pid; exit=$?");
      }

      if (TRACE_SIGNALS) {
        _warn("<sg> POE::Kernel will poll again immediately");
      }

      next;
    }

    # The only other negative value waitpid(2) should return is -1.
    # This is highly unlikely, but it's necessary to catch
    # portability problems.
    #
    # TODO - Find a way to test this.

    _trap "internal consistency error: waitpid returned $pid"
    if $pid != -1;

    # If the error is an interrupted syscall, poll again right away.

    if ($! == EINTR) {
      if (TRACE_SIGNALS) {
        _warn(
          "<sg> POE::Kernel's waitpid(2) was interrupted.\n",
          "POE::Kernel will poll again immediately.\n"
        );
      }
      next;
    }

    # No child processes exist.  TODO This is different than
    # children being present but running.  Maybe this condition
    # could halt polling entirely, and some UNIVERSAL::fork wrapper
    # could restart polling when processes are forked.

    if ($! == ECHILD) {
      if (TRACE_SIGNALS) {
        _warn("<sg> POE::Kernel has no child processes");
      }
      last;
    }

    # Some other error occurred.

    if (TRACE_SIGNALS) {
      _warn("<sg> POE::Kernel's waitpid(2) got error: $!");
    }
    last;
  }

  # If waitpid() returned 0, then we have child processes.

  $kr_child_procs = !$pid;


  unless ( USE_SIGCHLD ) {
    # The poll loop is over.  Resume slowly polling for signals.

    if (TRACE_SIGNALS) {
      _warn("<sg> POE::Kernel will poll again after a delay");
    }

    if ($polling_for_signals) {
      $self->_data_sig_enqueue_poll_event();
    }
    else {
      $self->_idle_queue_shrink();
    }
  }
}

# Are there child processes worth waiting for?
# We don't really care if we're not polling for signals.
# TODO - Will this change?

sub _data_sig_child_procs {
  return if !USE_SIGCHLD and !$polling_for_signals;
  return $kr_child_procs;
}

1;

__END__

=head1 NAME

POE::Resource::Signals - internal signal manager for POE::Kernel

=head1 SYNOPSIS

There is no public API.

=head1 DESCRIPTION

POE::Resource::Signals is a mix-in class for POE::Kernel.  It provides
the features needed to manage signals.  It is used internally by
POE::Kernel, so it has no public interface.

=head1 SEE ALSO

See L<POE::Kernel/Signals> for a deeper discussion about POE's signal
handling.

See L<POE::Kernel/Signal Watcher Methods> for POE's public signals
API.

See L<POE::Kernel/Resources> for for public information about POE
resources.

See L<POE::Resource> for general discussion about resources and the
classes that manage them.

=head1 BUGS

None known.

=head1 AUTHORS & COPYRIGHTS

Please see L<POE> for more information about authors and contributors.

=cut

# rocco // vim: ts=2 sw=2 expandtab
# TODO - Edit.

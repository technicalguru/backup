package Backup::Notification::Email;
use strict;

sub new {
	my ($class, %args) = @_;
	my $self = \%args;
	bless $self, $class;
	return $self;
}

sub notify {
	my $self = shift;
	my $file = shift;

	my $rc = 0;
	if ($self->{config}->{method} eq 'sendmail') {
		$rc = $self->sendmail($file);
	} else {
		$self->{log}->error('No such email method: '.$self->{config}->{method});
	}

	if ($rc) {
		$self->{log}->info('Log sent to: '.$self->{config}->{recipient});
	}

}

sub sendmail {
	my $self = shift;
	my $file = shift;

	my $subject = '['.$self->{main}->{config}->{hostname}.'] Backup Errors'; 
	my $cmd = '(echo "Subject: '.$subject.'"; echo ""; cat "'.$file.'") | '.$self->{config}->{sendmail}.' -f '.$self->{config}->{sender}.' -F "'.$self->{config}->{senderName}.'" '.$self->{config}->{recipient};
	if ($self->{executor}->execute($cmd)) {
		$self->{log}->error('Sending failed. See log at: '.$self->{executor}->{logfile});
		return 0;
	}
	return 1;
}

1;


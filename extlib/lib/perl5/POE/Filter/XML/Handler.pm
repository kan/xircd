package POE::Filter::XML::Handler;

use strict;
use warnings;
use POE::Filter::XML::Node;
use base('XML::SAX::Base');

our $VERSION = '0.38';

sub clone()
{
	my $self = shift(@_);

	return POE::Filter::XML::Handler->new($self->{'notstreaming'});
}

sub new()
{
	my ($class, $notstreaming) = @_;
	my $self = 
	{
		'depth'		=> $notstreaming ? 0 : -1,
		'currnode'	=> undef,
		'finished'	=> [],
		'parents'	=> [],
		'notstreaming'	=> $notstreaming,
	};

	bless $self, $class;

	return $self;
}

sub reset()
{	
	my $self = shift;

	$self->{'currnode'} = undef;
	$self->{'finished'} = [];
	$self->{'parents'} = [];
	$self->{'depth'} = $self->{'notstreaming'} ? 0 : -1;
	$self->{'count'} = 0;
}

sub start_element() 
{
	my ($self, $data) = @_;
	
	if($self->{'depth'} == -1) 
	{	    
		#start of a document: make and return the tag

		my $start = POE::Filter::XML::Node->new($data->{'Name'});
        $start->stream_start(1);
		
		foreach my $attrib (values %{$data->{'Attributes'}})
		{
			$start->setAttribute($attrib->{'Name'}, $attrib->{'Value'});
		}

		push(@{$self->{'finished'}}, $start);
		
		$self->{'count'}++;
		$self->{'depth'}++;
			
	} else {
	
		$self->{'depth'}++;

		# Top level fragment
		if($self->{'depth'} == 1)
		{
			$self->{'currnode'} = POE::Filter::XML::Node->new($data->{'Name'});
			
			foreach my $attrib (values %{$data->{'Attributes'}})
			{
				$self->{'currnode'}->setAttribute
				(
					$attrib->{'Name'}, 
					$attrib->{'Value'}
				);
			}

			push(@{$self->{'parents'}}, $self->{'currnode'});
		
		} else {
		    
			# Some node within a fragment
			my $kid = POE::Filter::XML::Node->new($data->{'Name'});
            $self->{'currnode'}->appendChild($kid);
			
			foreach my $attrib (values %{$data->{'Attributes'}})
			{
				$kid->setAttribute($attrib->{'Name'}, $attrib->{'Value'});
			}

			push(@{$self->{'parents'}}, $self->{'currnode'});
			
			$self->{'currnode'} = $kid;
		}
	}

    $self->SUPER::start_element($data);
}

sub end_element()
{
	my ($self, $data) = @_;
	
	if($self->{'depth'} == 0)
	{
		my $end = POE::Filter::XML::Node->new($data->{'Name'});
        $end->stream_end(1);
		
		push(@{$self->{'finished'}}, $end);
		
		$self->{'count'}++;
		
	} elsif($self->{'depth'} == 1) {
		
		push(@{$self->{'finished'}}, $self->{'currnode'});
		
		$self->{'count'}++;
		
		delete $self->{'currnode'};
		
		pop(@{$self->{'parents'}});
	
	} else {
	
		$self->{'currnode'} = pop(@{$self->{'parents'}});
	}

	$self->{'depth'}--;
    
    $self->SUPER::end_element($data);
}

sub characters() 
{
	my($self, $data) = @_;
    
	if($self->{'depth'} == 0)
	{
		return;
	}

	$self->{'currnode'}->appendText($data->{'Data'});
    
    $self->SUPER::characters($data);
}

sub get_node()
{
	my $self = shift;
	$self->{'count'}--;
	return shift(@{$self->{'finished'}});
}

sub finished_nodes()
{
	my $self = shift;
	return $self->{'count'};
}

1;

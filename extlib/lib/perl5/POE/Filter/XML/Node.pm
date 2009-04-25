package POE::Filter::XML::Node;
use warnings;
use strict;

use 5.010;
use Hash::Util('fieldhash');
use XML::LibXML(':libxml');
use base('XML::LibXML::Element', 'Exporter');

our $VERSION = '0.38';

our @EXPORT = qw/ &ordain /;

sub new()
{
    my $class = shift(@_);
    my $name = shift(@_);
    my $attrs = shift(@_);

    my $self = $class->SUPER::new($name);
    
    bless($self, $class);
    
    if(defined($attrs))
    {
        $self->setAttributes($attrs);
    }
    
    return $self;
}

sub stream_start()
{
    my $self = shift(@_);
    fieldhash state %stream_start;
    if(@_)
    {
        $stream_start{$self} = shift(@_);
    }
    else
    {
        return $stream_start{$self};
    }
}

sub stream_end()
{
    my $self = shift(@_);
    fieldhash state %stream_end;
    if(@_)
    {
        $stream_end{$self} = shift(@_);
    }
    else
    {
        return $stream_end{$self};
    }
}

sub cloneNode()
{
	my $self = shift(@_);
    my $deep = shift(@_);
    
    my $clone = $self->SUPER::cloneNode($deep);
    
    bless($clone, ref($self));
    
    $clone->stream_start($self->stream_start());
    $clone->stream_end($self->stream_end());
    
    return $clone;
}

sub ordain
{
    my $node = shift(@_);
    return bless($node, __PACKAGE__);
}

sub setAttributes()
{
	my ($self, $array) = @_;

	for(my $i = 0; $i < scalar(@$array); $i++)
	{
        if($array->[$i] eq 'xmlns')
        {
            $self->setNamespace($array->[++$i], '', 0);
        }
        else
        {
		    $self->setAttribute($array->[$i], $array->[++$i]);
        }
	}
	
	return $self;
}

sub getAttributes()
{
	my $self = shift(@_);
    
    my $attributes = {};

    foreach my $attrib ($self->attributes())
    {
        if($attrib->nodeType == XML_ATTRIBUTE_NODE)
        {
            $attributes->{$attrib->nodeName()} = $attrib->value();
        }
    }

    return $attributes;
}

sub appendChild()
{
    my $self = shift(@_);
    my $child = shift(@_);
    my $attrs = shift(@_);

    my $node;

    if(ref($child) and $child->isa(__PACKAGE__))
    {
        $self->SUPER::appendChild($child);
        
        $node = $child;
        
        if(defined($attrs))
        {
            $node->setAttributes($attrs);
        }
    }
    else
    {
        $node = POE::Filter::XML::Node->new($child, $attrs);
        $self->appendChild($node);
    }
    
    return $node;
}

sub getSingleChildByTagName()
{
    my $self = shift(@_);
    my $name = shift(@_);
    
    my $node = ($self->getChildrenByTagName($name))[0];
    return undef if not defined($node);
    bless($node, ref($self));
    return $node;
}
						
sub getChildrenHash()
{
	my $self = shift(@_);
    
    my $children = {};

    foreach my $child ($self->getChildrenByTagName("*"))
    {
        bless($child, ref($self));

        my $name = $child->nodeName();
        
        if(!exists($children->{$name}))
        {
            $children->{$name} = [];
        }
        
        push(@{$children->{$name}}, $child);
    }

    return $children;
}

sub toString()
{
    my $self = shift(@_);
    my $formatted = shift(@_);

    if($self->stream_start())
    {
        my $string = '<';
        $string .= $self->nodeName();
        foreach my $attr ($self->attributes())
        {
            $string .= sprintf(' %s="%s"', $attr->nodeName(), $attr->value());
        }
        $string .= '>';
        return $string;
    }
    elsif ($self->stream_end())
    {
        return sprintf('</%s>', $self->nodeName()); 
    }
    else
    {
        return $self->SUPER::toString(defined($formatted) ? 1 : 0);
    }
}

1;

__END__

=pod

=head1 NAME

POE::Filter::XML::Node - An enhanced XML::LibXML::Element subclass.

=head1 SYNOPSIS

use 5.010;

use POE::Filter::XML::Node;

my $node = POE::Filter::XML::Node->new('iq');

$node->setAttributes(
    ['to', 'foo@other', 
    'from', 'bar@other',
    'type', 'get']
);

my $query = $node->addNewChild('jabber:iq:foo', 'query');

$query->appendTextChild('foo_tag', 'bar');

say $node->toString();

-- 

(newlines and tabs for example only)

 <iq to='foo@other' from='bar@other' type='get'>
   <query xmlns='jabber:iq:foo'>
     <foo_tag>bar</foo_tag>
   </query>
 </iq>

=head1 DESCRIPTION

POE::Filter::XML::Node is a XML::LibXML::Element subclass that aims to provide
a few extra convenience methods and light integration into a streaming context.

=head1 METHODS

=over 4

=item stream_start($bool) [public]

stream_start() called without arguments returns a bool on whether or not the
node in question is the top level document tag. In an xml stream such as
XMPP this is the <stream:stream> tag. Called with a single argument (a bool)
sets whether this tag should be considered a stream starter.

This method is significant because it determines the behavior of the toString()
method. If stream_start() returns bool true, the tag will not be terminated.
(ie. <iq to='test' from='test'> instead of <iq to='test' from='test'B</>>)

=item stream_end($bool) [public]

stream_end() called without arguments returns a bool on whether or not the
node in question is the closing document tag in a stream. In an xml stream
such as XMPP, this is the </stream:stream>. Called with a single argument (a 
bool) sets whether this tag should be considered a stream ender.

This method is significant because it determines the behavior of the toString()
method. If stream_end() returns bool true, then any data or attributes or
children of the node is ignored and an ending tag is constructed. 

(ie. </iq> instead of <iq to='test' from='test'><child/></iq>)

=item setAttributes($array_ref) [public]

setAttributes() accepts a single arguement: an array reference. Basically you
pair up all the attributes you want to be into the node (ie. [attrib, value])
and this method will process them using setAttribute(). This is just a 
convenience method.

If one of the attributes is 'xmlns', setNamespace() will be called with the 
value used as the $nsURI argument, with no prefix, and not activated.

 eg. 
 ['xmlns', 'http://foo']
        |
        V
 setNamespace($value, '', 0)
        |
        V
 <node xmlns="http://foo"/>

=item getAttributes() [public]

This method returns all of the attribute nodes on the Element (filtering out 
namespace declarations).

=item getChildrenHash() [public]

getChildrenHash() returns a hash reference to all the children of that node.
Each key in the hash will be node name, and each value will be an array
reference with all of the children with that name. Each child will be 
blessed into POE::Filter::XML::Node.

=item getSingleChildByTagName($name) [public]

This is a convenience method that basically does:
 (getChildrenByTagName($name))[0]

The returned object will be a POE::Filter::XML::Node object.

=item new($name,[$array_ref]) [overriden]

The default XML::LibXML::Element constructor is overridden to provide some
extra functionality with regards to attributes. If the $array_ref argument is
defined, it will be passed to setAttributes().

Returns a newly constructed POE::Filter::XML::Node.

=item cloneNode($deep) [overridden]

This method overrides the base cloneNode() to propogate the stream_[start|end]
bits on the node being cloned. The $deep argument is passed unchanged to the 
base class.

This returns a POE::Filter::XML::Node object.

=item appendChild($name|$node,[$array_ref]) [overridden]

Depending on the arguments provided, this method either 1) instantiates a new
Node and appends to the subject or 2) appends the provided Node object. An
array reference of attributes may also be provided in either case, and if
defined, will be passed to setAttributes().

=item toString($formatted) [overridden]

toString() was overridden to provide special stringification semantics for when
stream_start and stream_end are boolean true. 

=back

=head1 FUNCTIONS

=over 4

=item ordain($element) [exported by default]

Use this exported function to get PFX::Nodes from XML::LibXML::Elements. This
is useful for inherited methods that by default return Elements instead of
Nodes.

=back

=head1 NOTES

This Node module is 100% incompatible with previous versions. Do NOT assume
this will upgrade cleanly.

When using XML::LibXML::Element methods, the objects returned will NOT be 
blessed into POE::Filter::XML::Node objects unless those methods are explictly
overriden in this module. Use POE::Filter::XML::Node::ordain to overcome this.

=head1 AUTHOR

Copyright (c) 2003 - 2009 Nicholas Perez. 
Released and distributed under the GPL.

=cut


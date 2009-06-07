#!/usr/bin/perl

package Class::Workflow;
use Moose;

use Class::Workflow::State::Simple;
use Class::Workflow::Transition::Simple;
use Class::Workflow::Instance::Simple;

our $VERSION = "0.10";

use Carp qw/croak/;
use Scalar::Util qw/refaddr/;

has initial_state => (
	isa => "Str | Object",
	is  => "rw",
);

has instance_class => (
	isa => "Str",
	is  => "rw",
	default => "Class::Workflow::Instance::Simple",
);

sub new_instance {
	my ( $self, %attrs ) = @_;

	if ( !$attrs{state} ) {
		if ( my $initial_state = $self->state( $self->initial_state ) ) {
			$attrs{state} = $initial_state;
		} else {
			croak "Explicit state not specified and no initial state is set in the workflow.";
		}
	}

	$self->instance_class->new( %attrs );
}

use tt fields => [qw/state transition/];
[% FOREACH field IN fields %]

has [% field %]_class => (
	isa => "Str",
	is  => "rw",
	default => "Class::Workflow::[% field | ucfirst %]::Simple",
);

has _[% field %]s => (
	isa => "HashRef",
	is  => "ro",
	default => sub { return {} },
);

sub [% field %]s {
	my $self = shift;
	values %{ $self->_[% field %]s };
}

sub [% field %]_names {
	my $self = shift;
	keys %{ $self->_[% field %]s };
}

sub [% field %] {
	my ( $self, @params ) = @_;

	if ( @params == 1 ) {
		if ( ref($params[0]) eq "HASH" ) {
			@params = %{ $params[0] };
		} elsif ( ref($params[0]) eq "ARRAY" ) {
			@params = @{ $params[0] };
		}
	}

	if ( !blessed($params[0]) and !blessed($params[1]) and @params % 2 == 0 ) {
		# $wf->state( name => "foo", transitions => [qw/bar gorch/] )
		return $self->create_or_set_[% field %]( @params );
	} elsif ( !ref($params[0]) and @params % 2 == 1 ) {
		# my $state = $wf->state("new", %attrs); # create new by name, or just get_foo
		return $self->create_or_set_[% field %]( name => @params )
	} elsif ( @params == 1 and blessed($params[0]) and $params[0]->can("name") ) {
		# $wf->state( $state ); # set by object (if $object->can("name") )
		return $self->add_[% field %]( $params[0]->name => $params[0] );
	} elsif ( @params == 2 and blessed($params[1]) and !ref($params[0]) ) {
		# $wf->state( foo => $state ); # set by name
		return $self->add_[% field %]( @params );
	} else {
		if ( @params == 1 and blessed($params[0]) ) {
			croak "The [% field %] $params[0] must support the 'name' method.";
		} else {
			croak "'[% field %]' was called with invalid parameters. Please consult the documentation.";
		}
	}
}

sub get_[% field %] {
	my ( $self, $name ) = @_;
	$self->_[% field %]s->{$name}
}

sub get_[% field %]s {
	my ( $self, @names ) = @_;
	@{ $self->_[% field %]s }{@names}
}

sub add_[% field %] {
	my ( $self, $name, $obj ) = @_;
	
	if ( exists $self->_[% field %]s->{$name} ) {
		croak "$name already exists, delete it first."
			unless refaddr($obj) == refaddr($self->_[% field %]s->{$name});
		return $obj;
	} else {
		return $self->_[% field %]s->{$name} = $obj;
	}
}

sub rename_[% field %] {
	my ( $self, $name, $new_name ) = @_;
	my $obj = $self->delete_[% field %]( $name );
	$obj->name( $new_name ) if $obj->can("name");
	$self->add_[% field %]( $new_name => $obj );
}

sub delete_[% field %] {
	my ( $self, $name ) = @_;
	delete $self->_[% field %]s->{$name};
}

sub create_[% field %] {
	my ( $self, $name, @attrs ) = @_;
	$self->add_[% field %]( $name => $self->construct_[% field %]( @attrs ) );
}

sub construct_[% field %] {
	my ( $self, %attrs ) = @_;
	my $class = delete($attrs{class}) || $self->[% field %]_class;
	$class->new( %attrs );
}

sub autovivify_[% field %]s {
	my ( $self, $thing ) = @_;

	no warnings 'uninitialized';
	if ( ref $thing eq "ARRAY" ) {
		return [ map { $self->[% field %]( $_ ) } @$thing ];
	} else {
		return $self->[% field %]( $thing );
	}
}

sub create_or_set_[% field %] {
	my ( $self, %attrs ) = @_;

	my $name = $attrs{name} || croak "Every [% field %] must have a name";

	$self->expand_attrs( \%attrs );

	if ( my $obj = $self->get_[% field %]( $name ) ) {
		delete $attrs{name};
		foreach my $attr ( keys %attrs ) {
			$obj->$attr( $attrs{$attr} );
		}

		return $obj;
	} else {
		return $self->create_[% field %]( $name, %attrs );
	}
}

[% END %]
no tt;

sub expand_attrs {
	my ($self, $attrs ) = @_;

	foreach my $key ( keys %$attrs ) {
		if ( my ( $type ) = ( $key =~ /(transition|state)/ ) ) {
			my $method = "autovivify_${type}s";
			$attrs->{$key} = $self->$method( $attrs->{$key} );
		}
	}
}

__PACKAGE__;

__END__

=pod

=head1 NAME

Class::Workflow - Light weight workflow system.

=head1 SYNOPSIS

	use Class::Workflow;

	# ***** NOTE *****
	#
	# This is a pretty long and boring example
	#
	# you probably want to see some flashy flash videos, so look in SEE ALSO
	# first ;-)
	#
	# ****************

	# a workflow object assists you in creating state/transition objects
	# it lets you assign symbolic names to the various objects to ease construction

	my $wf = Class::Workflow->new;

	# ( you can still create the state, transition and instance objects manually. )


	# create a state, and set the transitions it can perform

	$wf->state(
		name => "new",
		transitions => [qw/accept reject/],
	);

	# set it as the initial state

	$wf->initial_state("new");


	# create a few more states

	$wf->state(
		name => "open",
		transitions => [qw/claim_fixed reassign/],
	);

	$wf->state(
		name => "rejected",
	);


	# transitions move instances from state to state
	
	# create the transition named "reject"
	# the state "new" refers to this transition
	# the state "rejected" is the target state

	$wf->transition(
		name => "reject",
		to_state => "rejected",
	);


	# create a transition named "accept",
	# this transition takes a value from the context (which contains the current acting user)
	# the context is used to set the current owner for the bug

	$wf->transition(
		name => "accept",
		to_state => "opened",
		body => sub {
			my ( $transition, $instance, $context ) = @_;
			return (
				owner => $context->user, # assign to the use who accepted it
			);
		},
	);


	# hooks are triggerred whenever a state is entered. They cannot change the instance
	# this hook calls a hypothetical method on the submitter object

	$wf->state( "reject" )->add_hook(sub {
		my ( $state, $instance ) = @_;
		$instance->submitter->notify("Your item has been rejected");
	});


	# the rest of the workflow definition is omitted for brevity


	# finally, use this workflow in the action that handles bug creation

	sub new_bug {
		my ( $submitter, %params ) = @_;

		return $wf->new_instance(
			submitter => $submitter,
			%params,
		);
	}

=head1 DESCRIPTION

Workflow systems let you build a state machine, with transitions between
states.

=head1 EXAMPLES

There are several examples in the F<examples> directory, worth looking over to
help you understand and to learn some more advanced things.

The most important example is probably how to store a workflow definition (the
states and transitions) as well as the instances using L<DBIx::Class> in a
database.

=head2 Bug Tracker Example

One of the simplest examples of a workflow which you've probably used is a bug
tracking application:

=over 4

The initial state is 'new'

=item new

New bugs arrive here.

=over 4

=item reject

This bug is not valid.

Target state: C<rejected>.

=item accept

This bug needs to be worked on.

Target state: C<open>.

=back

=item rejected

This is the state where deleted bugs go, it has no transitions.

=item open

The bug is being worked on right now.

=over 4

=item reassign

Pass the bug to someone else.

Target state: C<unassigned>.

=item fixed

The bug looks fixed, and needs verifification.

Target state: C<awaiting_approval>.

=back

=item unassigned

The bug is waiting for a developer to take it.

=over 4

=item take

Volunteer to handle the bug.

Target state: C<open>.

=back

=item awaiting_approval

The submitter needs to verify the bug.

=over 4

=item resolved

The bug is resolved and can be closed.

Target state: C<closed>

=item unresolved

The bug needs more work.

Target state: C<open>

=item closed

This is, like rejected, an end state (it has no transitions).

=back

If you read through this very simple state machine you can see that it
describes the steps and states a bug can go through in a bug tracking system.
The core of every workflow is a state machine.

=head1 INSTANCES

On the implementation side, the core idea is that every "item" in the system
(in our example, a bug) has a workflow B<instance>. This instance represents
the current position of the item in the workflow, along with history data (how
did it get here).

In this implementation, the instance is usually a consumer of
L<Class::Workflow::Instance>, typically L<Class::Workflow::Instance::Simple>.

So, when you write your MyBug class, it should look like this (if it were written
in L<Moose>):

	package MyBug;
	use Moose;

	has workflow_instance => (
		does => "Class::Workflow::Instance", # or a more restrictive constraint
		is   => "rw",
	);

Since this system is purely functional (at least if your transitions are), you
need to always set the instance after applying a transition.

For example, let's say you have a handler for the "accept" action, to change
the instance's state it would do something like this:

	sub accept {
		my $bug = shift;

		my $wi = $bug->workflow_instance;
		my $current_state = $wi->state;

		# if your state supports named transitions	
		my $accept = $current_state->get_transition( "accept" )
			or die "There's no 'accept' transition in the current state";

		my $wi_accepted = $accept->apply( $wi );

		$bug->workflow_instance( $wi_accepted );
	}

=head1 RESTRICTIONS

Now let's decsribe some restrictions on this workflow.

=over 4

=item *

Only the submitter can approve the bug as resolved.

=item *

Only the developer can claim the bug was fixed, and reassign the bug.

=item *

Any developer (but not the submitter) can accept a bug as valid, into the
'open' state.

=back

A workflow system will not only help in modelying the state machine, but also
help you create restrictions on how states need to be changed, etc.

The implementation of restrictions is explained after the next section.

=head1 CONTEXTS

In order to implement these restrictions cleanly you normally use a context
object (a default one is provided in L<Class::Workflow::Context> but you can
use B<anything>).

This is typically the first (and sometimes only) argument to all transition
applications, and it describes the context that the transition is being applied
in, that is who is applying the transition, what are they applying it with, etc
etc.

In our bug system we typically care about the user, and not much else.

Imagine that we have a user class:

	package MyUser;

	has id => (
		isa => "Num",
		is  => "ro",
		default => sub { next_unique_id() };
	);

	has name => (
		...
	);

We can create a context like this:

	package MyWorkflowContext;
	use Moose;

	extends "Class::Workflow::Context";

	has user => (
		isa => "MyUser",
		is  => "rw",
	);

to contain the "current" user.

Then, when we apply the transition a bit differently:

	sub accept {
		my ( $bug, $current_user ) = @_;

		my $wi = $bug->workflow_instance;
		my $current_state = $wi->state;

		# if your state supports named transitions	
		my $accept = $current_state->get_transition( "accept" )
			or croak "There's no 'accept' transition in the current state";

		my $c = MyWorkflowContext->new( user => $current_user );
		my $wi_accepted = $accept->apply( $wi, $c );

		$bug->workflow_instance( $wi_accepted );
	}

And the transition has access to our C<$c> object, which references the current
user.

=head1 IMPLEMENTING RESTRICTIONS

In order to implement the restrictions we specified above we need to know who
the submitter and owner of the item are.

For this we create our own instance class as well:

	package MyWorkflowInstance;
	use Moose;

	extends "Class::Workflow::Instance::Simple";

	has owner => (
		isa => MyUser",
		is  => "ro", # all instance fields should be read only
	);

	has submitter => (
		isa => MyUser",
		is  => "ro", # all instance fields should be read only
	);

When the first instance is created the current user is set as the submitter.

Then, as transitions are applied they can check for the restrictions.

This is typically not done in the actual transition body, but rather in
validation hooks. L<Class::Workflow::Transition::Validate> provides a stanard
hook, and L<Class::Workflow::Transition::Simple> provides an even easier
interface for this:

	my $fixed = Class::Workflow::Transition::Simple->new(
		name          => 'fixed',
		to_transition => $awaiting_approval,
		validators    => [
			sub {
				my ( $self, $instance, $c ) = @_;
				die "Not owner" unless $self->instance->owner->id == $c->user->id;
			},
		],
		body => sub {
			# ...
		},
	);

=head1 PERSISTENCE

Persistence in workflows involves saving the workflow instance as a
relationship of the item whose state it represents, or even treating the
instance as the actual item.

In any case, right now there are no turnkey persistence layers available.

A fully working L<DBIx::Class> example can be found in the F<examples/dbic>
directory, but setup is manual. Serialization based persistence (with e.g.
L<Storable>) is trivial as well.

See L<Class::Workflow::Cookbook> for more details.

=head1 ROLES AND CLASSES

Most of the Class::Workflow system is implemented using roles to specify
interfaces with reusable behavior, and then ::Simple classes which mash up a
bunch of useful roles.

This means that you have a very large amount of flexibility in how you compose
your state/transition objects, allowing good integration with most existing
software.

This is achieved using L<Moose>, specifically L<Moose::Role>.

=head1 THIS CLASS

L<Class::Workflow> objects are utility objects to help you create workflows and
instances without worrying too much about the state and transition objects.

It's usage is overviewed in the L</SYNOPSIS> section.

=head1 FIELDS

=over 4

=item instance_class

=item state_class

=item transition_class

These are the classes to instantiate with.

They default to L<Class::Workflow::Instance::Simple>,
L<Class::Workflow::State::Simple> and L<Class::Workflow::Transition::Simple>.

=back

=head1 METHODS

=over 4

=item new_instance

Instantiate the workflow

=item initial_state

Set the starting state of instances.

=item states

=item transitions

Return all the registered states or transitions.

=item state_names

=item transition_names

Return all the registered state or transition names.

=item state

=item transition

These two methods create update or retrieve state or transition objects.

They have autovivification semantics for ease of use, and are pretty lax in
terms of what they accept.

More formal methods are presented below.

They have several forms:

	$wf->state("foo"); # get (and maybe create) a new state with the name "foo"

	$wf->state( foo => $object ); # set $object as the state by the name "foo"

	$wf->state( $object ); # register $object ($object must support the ->name method )

	# create or update the state named "foo" with the following attributes:
	$wf->state(
		name       => "foo",
		validators => [ sub { ... } ],
	);

	# also works with implicit name:
	$wf->state( foo =>
		validators  => [ sub { ... } ],
	);

(wherever ->state is used ->transition can also be used).

Additionally, whenever you construct a state like this:

	$wf->state(
		name        => "foo",
		transitions => [qw/t1 t2/],
	);

the parameters are preprocessed so that it's as if you called:

	my @transitions = map { $wf->state($_) } qw/t1 t2/;
	$wf->state(
		name        => "foo",
		transitions => [@transitions],
	);

so you don't have to worry about creating objects first.

=item add_state $name, $object

=item add_transition $name, $object

Explicitly register an object by the name $name.

=item delete_state $name

=item delete_transition $name

Remove an object by the name $name.

Note that this will B<NOT> remove the object from whatever other object reference it, so that:

	$wf->state(
		name        => "foo",
		transitions => ["bar"],
	);

	$wf->delete_transition("bar");

will not remove the object that was created by the name "bar" from the state
"foo", it's just that the name has been freed.

Use this method with caution.

=item rename_state $old, $new

=item rename_transition $old, $new

Change the name of an object.

=item get_state $name

=item get_transition $name

Get the object by that name or return undef.

=item create_state $name, @args

=item create_transition $name, @args

Call C<construct_state> or C<construct_transition> and then C<add_state> or
C<add_transition> with the result.

=item construct_state @args

=item construct_transition @args

Call ->new on the appropriate class.

=item expand_attrs \%attrs

This is used by C<create_or_set_state> and C<create_or_set_transition>, and
will expand the attrs by the names C<to_state>, C<transition> and
C<transitions> to be objects instead of string names, hash or array references,
by calling C<autovivify_transitions> or C<autovivify_states>.

In the future this method might be more aggressive, expanding suspect attrs.

=item autovivify_states @things

=item autovivify_transitions @things

Coerce every element in @things into an object by calling
C<< $wf->state($thing) >> or C<< $wf->transition($thing) >>.

=item create_or_set_state %attrs

=item create_or_set_transition %attrs

If the object by the name $attrs{name} exists, update it's attrs, otherwise
create a new one.

=back

=head1 SEE ALSO

L<Workflow> - Chris Winters' take on workflows - it wasn't simple enough for me
(factoring out the XML/factory stuff was difficult and I needed a much more
dynamic system).

L<http://is.tm.tue.nl/research/patterns/> - lots of explanation and lovely
flash animations.

L<Class::Workflow::YAML> - load workflow definitions from YAML files.

L<Class::Workflow::Transition::Simple>, L<Class::Workflow::State::Simple>,
L<Class::Workflow::Instance::Simple> - easy, useful classes that perform all
the base roles.

L<Moose>

=head1 VERSION CONTROL

This module is maintained using git. You can get the latest version from
git://github.com/nothingmuch/class-workflow.git

=head1 AUTHOR

Yuval Kogman <nothingmuch@woobling.org>

=head1 COPYRIGHT & LICENSE

	Copyright (c) 2006-2008 Infinity Interactive, Yuval Kogman. All rights
	reserved. This program is free software; you can redistribute
	it and/or modify it under the same terms as Perl itself.

=cut



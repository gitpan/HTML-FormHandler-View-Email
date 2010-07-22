package HTML::FormHandler::View::Email;

use Moose;
use Carp;
use Email::Sender::Simple qw/sendmail/;
use Email::Simple;
use Email::Simple::Creator;
use Email::Sender::Transport::SMTP;

our $VERSION = '0.04101';

extends 'HTML::FormHandler';

sub email {
    my $self = shift;
    croak 'No params available' unless $self->params;
    my $body = $self->build_body;
    $self->validate_header;
    my $mail = $self->build_email($body);
    eval { $self->mailer_args; };
    if (!$@) {
        $self->send_mail_smtp($mail);
    }
    else {
        $self->send_mail($mail);
    }
}

sub send_mail {
    my ($self, $mail) = @_;
    sendmail($mail) or carp 'Email failed to send';
}

sub send_mail_smtp {
    my ($self, $mail) = @_;
    my $transport = Email::Sender::Transport::SMTP->new({
        host => $self->mailer_args->{host},
        port => $self->mailer_args->{port},
        sasl_username => $self->mailer_args->{username} || '',
        sasl_password => $self->mailer_args->{password} || '',
       });
    sendmail($mail, { transport => $transport }) or carp 'Email failed to send';
}

sub build_email {
    my ($self, $body) = @_;
    my $mail = Email::Simple->create(
        header => [
            To => $self->to,
            From => $self->from,
            Subject => $self->subject || '',
        ],
        body => $body."\n",
        );
    return $mail;
}

sub build_body {
    my $self = shift;
    my $match = $self->build_matched; 
    my @parts;
    # builds email body
    for (keys %$match) {
        push @parts, ucfirst $_.": ".$match->{$_};
    }
    my $body = join("\n", @parts);
    return $body;
}

sub build_matched {
    my $self = shift;
    eval { $self->fields_list; };
    my $fields;
    if ($@) {
        $fields = $self->fields;
    }
    else {
        my $field_list = $self->fields_list;
        foreach my $field (@$field_list) {
            push @$fields, $self->field($field) or carp 'Invalid name specified in list';
        }
    }
    croak 'No fields found, email cant be blank' unless @$fields;
    my $match = $self->match($fields);
    return $match;
}

sub match {
    my ($self, $fields) = @_;
    my $params = $self->params;
    my $match;
    foreach my $field (@$fields) {
        my $name = $field->name;
        if ($params->{$name} && $name ne 'submit') {
            $match->{$name} = $params->{$name};
        }
    }
    return $match;
}

sub validate_header {
    my $self = shift;
    eval { $self->to;
           $self->from;
    };
    croak 'to/from fields required in form class' if $@;
}
    
__PACKAGE__->meta->make_immutable;

use namespace::autoclean;

1;

=head1 NAME

HTML::FormHandler::View::Email - Easily and dynamically send email from your HTML::FormHandler forms in Catalyst

=head1 SYNOPSIS

In your form class:
    
    use 'HTML::FormHandler::Moose';
    extends 'HTML::FormHandler::View::Email';

    has 'to' => ( is => 'rw', default => 'aesop@unicornmob.com' );
    
    has 'from' => ( is => 'rw', default => 'noreply@unicornmob.com' );

    has 'subject' => ( is => 'rw', default => 'Get on Star Trek: TNG and face Reiker the bill collector' );

If you want to use SMTP:

    has 'mailer_args' => ( is => 'rw, default => sub {
       { host => 'smtp.unicornmob.com',
         username => 'aesop@unicornmob.com',
         password => 'secret',
         port => '25' } }, );

    has_field .... # the rest of your form class


In your Catalyst controller:

    # see HTML::FormHandler::Manual
    return unless $form->process( .... )

    # be sure call process first to validate the fields before firing off any emails
    return unless $form->email;

=head1 ATTRIBUTES

Set these in your form class:

to - Delivery email address, required.

from - Sender email address, required.

subject - Email subject, not required.

mailer_args - Required only if using SMTP for delivery.

host - SMTP host address, required only if using SMTP for delivery.

username - Valid username, used for authentication with the SMTP host, required only if using SMTP for delivery.

password - Valid password, used for authentication with the SMTP host, required only if using SMTP for delivery.

port - Port number, defaults to 25, required only if using SMTP for delivery.

fields_list - You can specify a list of fields in an arrayref that you'd like to be emailed, not required:

    has 'fields_list' => ( is => 'rw', default => sub { ['name', 'address', 'phone'] } );

=head1 METHODS

$form->email - Processes and sends the Email.

=head1 SUBCLASS IT

It would be good practice to create a seperate form class with only the required attributes specified (to, from, etc.) and then 'extends' it in all the forms classes you'd like to create emails from.

=head1 NOTE ON SMTP

If you are using SMTP and dont specify a host it will default to localhost, meaning that it is possible that the email will never be delivered, especially if your SMTP server is configured improperly. Double check both that and that the username and password are set to the correct values. Nine times out of ten this will fix your problem.

If you arent using an external SMTP server, make sure your MTA (e.g. postfix) is running on the box you are using this module on.

=head1 SEE ALSO

L<HTML::FormHandler::Manual>

L<HTML::FormHandler::Moose>

L<HTML::FormHandler::Model::DBIC>

L<Catalyst::Manual::Intro>

L<Email::Sender::Simple>

=head1 AUTHOR

aesop E<lt>aesop@unicornmob.comE<gt>

Big thanks to gshank and all the HTML::FormHandler contributers for writing such awesome modules.

=head1 COPYRIGHT

This library is free software, you can redistribute it and/or modify it under 
the same terms as Perl itself.

=cut 
    

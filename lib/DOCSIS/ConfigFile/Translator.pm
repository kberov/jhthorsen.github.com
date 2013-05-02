package DOCSIS::ConfigFile::Translator;

=head1 NAME

DOCSIS::ConfigFile::Translator - Translate docsis config files

=head1 DESCRIPTION

This module is an addition to L<DOCSIS::ConfigFile>, which can
translate between binary and more simple (readable?) formats.

=cut

use strict;
use warnings;
use Config::General;
use DOCSIS::ConfigFile;

my $docsis = DOCSIS::ConfigFile->new;

=head1 METHODS

=head2 text_to_binary

  $str = $class->text_to_binary($shared_secret, $str);

=cut

sub text_to_binary {
  my($class, $shared_secret, $text) = @_;

  return $class->_hash_to_binary($shared_secret, {
    Config::General->new(-String => $text)->getall
  });
}

sub _hash_to_binary {
  my($class, $shared_secret, $hash) = @_;

  $docsis->shared_secret($shared_secret);
  $docsis->encode($class->_hash_to_list($hash));
}

sub _hash_to_list {
  my($class, $hash) = @_;
  my @list;

  local $_;

  while(my($name, $value) = each %$hash) {
    if(ref $value eq '') {
      push @list, { name => $name, value => $value };
    }
    elsif(ref $value eq 'HASH') {
      if($name eq 'SnmpMibObject') {
        push @list, $class->_snmp_mib_object_to_struct($value);
      }
      elsif($name eq 'VendorSpecific') {
        push @list, $class->_vendor_specific_to_struct($value);
      }
      else {
        push @list, { name => $name, nested => $class->_hash_to_list($value) };
      }
    }
    elsif(ref $value eq 'ARRAY') {
      push @list, @{ $class->_hash_to_list($_) } for(@$value);
    }
    else {
      die "Cannot translate $value";
    }
  }

  return \@list;
}

sub _vendor_specific_to_struct {
  my($class, $value) = @_;
  my($name) = keys %$value;
  my @nested;

  while(my($type, $value) = each %{ $value->{$name } }) {
    my $length = 1 + int hex($value) / 256;
    push @nested, { type => $type, length => $length, value => hex $value };
  }

  return {
    name => 'VendorSpecific',
    value => $name,
    nested => \@nested,
  };
}

sub _snmp_mib_object_to_struct {
  my($class, $value) = @_;
  my($oid) = keys %$value;

  return {
    name => 'SnmpMibObject',
    value => {
      oid => $oid,
      type => (keys %{ $value->{$oid} })[0],
      value => (values %{ $value->{$oid} })[0],
    },
  };
}

=head2 binary_to_text

    $str = $class->binary_to_text($str);

=cut

sub binary_to_text {
  my $class = shift;
  my $hash = $class->_binary_to_hash(@_);
  my @text;

  for my $key (sort { __sort_config_keys($hash) } keys %$hash) {
    push @text, Config::General->new({ $key => $hash->{$key} })->save_string;
  }

  return join '', @text;
}

sub __sort_config_keys {
  ref $_[0]->{$a}[0] cmp ref $_[0]->{$b}[0] || $a cmp $b;
}


sub _binary_to_hash {
  my($class, $binary) = @_;

  $docsis->shared_secret(''); # TODO
  $class->_list_to_hash($docsis->decode(\$binary));
}

sub _list_to_hash {
  my($class, $list) = @_;
  my $hash;

  for my $struct (@$list) {
    my $name = $struct->{name} or next;

    $hash->{$name} ||= [];

    if($name eq 'SnmpMibObject') {
      push @{ $hash->{$name} }, {
        $struct->{value}{oid} => { @{ $struct->{value} }{qw/ type value /} },
      };
    }
    elsif($name eq 'VendorSpecific') {
      push @{ $hash->{$name} }, {
        $struct->{value} => { map { @$_{qw/ type value /} } @{ $struct->{nested} } },
      };
    }
    elsif($struct->{nested}) {
      push @{ $hash->{$name} }, $class->_list_to_hash($struct->{nested});
    }
    else {
      push @{ $hash->{$name} }, $struct->{value};
    }
  }

  delete $hash->{CmMic};
  delete $hash->{CmtsMic};
  delete $hash->{GenericTLV};

  return $hash;
}

=head1 AUTHOR

Jan Henning Thorsen - C<jhthorsen@cpan.org>

=cut

1;

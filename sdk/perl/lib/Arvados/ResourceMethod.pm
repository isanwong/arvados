package Arvados::ResourceMethod;
use Carp;
use Data::Dumper;

sub new
{
    my $class = shift;
    my $self = {};
    bless ($self, $class);
    return $self->_init(@_);
}

sub _init
{
    my $self = shift;
    $self->{'resourceAccessor'} = shift;
    $self->{'method'} = shift;
    return $self;
}

sub execute
{
    my $self = shift;
    my $method = $self->{'method'};

    my $path = $method->{'path'};

    my %body_params;
    my %given_params = @_;
    while (my ($param_name, $param) = each %{$method->{'parameters'}}) {
        if ($param->{'required'} && !exists $given_params{$param_name}) {
            croak("Required parameter not supplied: $param_name");
        }
        elsif ($param->{'location'} eq 'path') {
            $path =~ s/{\Q$param_name\E}/$given_params{$param_name}/eg;
        }
        elsif (!exists $given_params{$param_name}) {
            ;
        }
        elsif ($param->{'type'} eq 'object') {
            my %param_value;
            my ($p, $v);
            while (($property_name, $property) = each %{$param->{'properties'}}) {
                if (!exists $given_params{$param_name}->{$property_name}) {
                    ;
                }
                elsif ($given_params{$param_name}->{$property_name} eq undef) {
                    $param_value{$property_name} = JSON::null;
                }
                elsif ($property->{'type'} eq 'boolean') {
                    $param_value{$property_name} = $given_params{$param_name}->{$property_name} ? JSON::true : JSON::false;
                }
                else {
                    $param_value{$property_name} = $given_params{$param_name}->{$property_name};
                }
            }
            $body_params{$param_name} = \%param_value;
        } elsif ($param->{'type'} eq 'boolean') {
            $body_params{$param_name} = $given_params{$param_name} ? JSON::true : JSON::false;
        } else {
            $body_params{$param_name} = $given_params{$param_name};
        }
    }
    my $r = $self->{'resourceAccessor'}->{'api'}->new_request;
    $r->set_uri($self->{'resourceAccessor'}->{'api'}->{'discoveryDocument'}->{'baseUrl'} . "/" . $path);
    $r->set_method($method->{'httpMethod'});
    $r->set_auth_token($self->{'resourceAccessor'}->{'api'}->{'authToken'});
    $r->set_query_params(\%body_params) if %body_params;
    $r->process_request();
    my $data, $headers;
    my ($status_number, $status_phrase) = $r->get_status();
    if ($status_number != 200) {
        croak("API call failed: $status_number $status_phrase\n". $r->get_body());
    }
    $data = $r->get_body();
    $headers = $r->get_headers();
    my $result = JSON::decode_json($data);
    if ($method->{'response'}->{'$ref'} =~ /List$/) {
        Arvados::ResourceProxyList->new($result, $self->{'resourceAccessor'});
    } else {
        Arvados::ResourceProxy->new($result, $self->{'resourceAccessor'});
    }
}

1;
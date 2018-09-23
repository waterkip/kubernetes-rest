package Kubernetes::REST::ListToRequest;
  use Moo;
  use HTTP::Tiny;
  use JSON::MaybeXS;
  use Kubernetes::REST::Error;

  has _json => (is => 'ro', default => sub { JSON::MaybeXS->new });

  sub callinfo_class {
    my ($self, $call) = @_;
    "Kubernetes::REST::Call::$call"
  }

  sub params2request {
    my ($self, $call, $user_params) = @_;

    my $call_object = eval { $self->callinfo_class($call)->new(@$user_params) };
    if ($@) {
      my $msg = $@;
      Kubernetes::REST::Error->throw(
        type => 'InvalidParameters',
        message => "Error in parameters to method $call",
        detail => $msg,
      );
    }

    my $body_struct;
    if ($call_object->can('_body_params')) {
      $body_struct = {};
      foreach my $param (@{ $call_object->_body_params }) {
        my $key = $param->{ name };
        my $value = $call_object->$key;
        next if (not defined $value);

        my $location = defined $param->{ location } ? $param->{ location } : $key;
        $body_struct->{ $location } = $value;
      }
    }

    my $params = {};
    foreach my $param (@{ $call_object->_query_params }) {
      my $key = $param->{ name };
      my $value = $call_object->$key;
      next if (not defined $value);

      my $location = defined $param->{ location } ? $param->{ location } : $key;
      $params->{ $location } = $value;
    }

    my $url_params = {};
    foreach my $param (@{ $call_object->_url_params }) {
      my $key = $param->{ name };
      my $value = $call_object->$key;
      next if (not defined $value);

      my $location = defined $param->{ location } ? $param->{ location } : $key;
      $url_params->{ $location } = $value;
    }
    my $url = $call_object->_url;
    $url =~ s/\:([a-z0-9_-]+)/$url_params->{ $1 }/ge;

    my $qstring = HTTP::Tiny->www_form_urlencode($params);
    my $req = Kubernetes::REST::HTTPRequest->new;
    $req->method($call_object->_method);
    $req->url(
      "$url?$qstring",
    );
    $req->headers({
      (defined $body_struct) ? ('Content-Type' => 'application/json') : (),
      Accept => 'application/json',
    });
    $req->content($self->_json->encode($body_struct)) if (defined $body_struct);

    return $req;
  }

1;

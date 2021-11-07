package MediaWiki::Bot;
use strict;
use warnings;
# ABSTRACT: a high-level bot framework for interacting with MediaWiki wikis
# VERSION

use HTML::Entities 3.28;
use Carp;
use Digest::MD5 2.39 qw(md5_hex);
use Encode qw(encode_utf8);
use MediaWiki::API 0.36;
use List::Util qw(sum);
use MediaWiki::Bot::Constants qw(:all);

use Exporter qw(import);
our @EXPORT_OK = @{ $MediaWiki::Bot::Constants::EXPORT_TAGS{all} };
our %EXPORT_TAGS = ( constants => \@EXPORT_OK );

use Module::Pluggable search_path => [qw(MediaWiki::Bot::Plugin)], 'require' => 1;
foreach my $plugin (__PACKAGE__->plugins) {
    #print "Found plugin $plugin\n";
    $plugin->import();
}

=head1 SYNOPSIS

    use MediaWiki::Bot qw(:constants);

    my $bot = MediaWiki::Bot->new({
        assert      => 'bot',
        host        => 'de.wikimedia.org',
        login_data  => { username => "Mike's bot account", password => "password" },
    });

    my $revid = $bot->get_last("User:Mike.lifeguard/sandbox", "Mike.lifeguard");
    print "Reverting to $revid\n" if defined($revid);
    $bot->revert('User:Mike.lifeguard', $revid, 'rvv');

=head1 DESCRIPTION

B<MediaWiki::Bot> is a framework that can be used to write bots which interface
with the MediaWiki API (L<http://en.wikipedia.org/w/api.php>).

=head1 METHODS

=head2 new

    my $bot = MediaWiki::Bot({
        host     => 'en.wikipedia.org',
        operator => 'Mike.lifeguard',
    });

Calling C<< MediaWiki::Bot->new() >> will create a new MediaWiki::Bot object. The
only parameter is a hashref with keys:

=over 4

=item *

I<agent> sets a custom useragent. It is recommended to use C<operator>
instead, which is all we need to do the right thing for you. If you really
want to do it yourself, see L<https://meta.wikimedia.org/wiki/User-agent_policy>
for guidance on what information must be included.

=item *

I<assert> sets a parameter for the AssertEdit extension (commonly 'bot')

Refer to L<http://mediawiki.org/wiki/Extension:AssertEdit>.

=item *

I<operator> allows the bot to send you a message when it fails an assert. This
is also the recommended way to customize the user agent string, which is
required by the Wikimedia Foundation. A warning will be emitted if you omit
this.

=item *

I<maxlag> allows you to set the maxlag parameter (default is the recommended 5s).

Please refer to the MediaWiki documentation prior to changing this from the
default.

=item *

I<protocol> allows you to specify 'http' or 'https' (default is 'http')

=item *

I<host> sets the domain name of the wiki to connect to

=item *

I<path> sets the path to api.php (with no leading or trailing slash)

=item *

I<login_data> is a hashref of credentials to pass to L</login>.

=item *

I<debug> - whether to provide debug output.

1 provides only error messages; 2 provides further detail on internal operations.

=back

For example:

    my $bot = MediaWiki::Bot->new({
        assert      => 'bot',
        protocol    => 'https',
        host        => 'en.wikimedia.org',
        agent       => sprintf(
            'PerlWikiBot/%s (https://metacpan.org/MediaWiki::Bot; User:Mike.lifeguard)',
            MediaWiki::Bot->VERSION
        ),
        login_data  => { username => "Mike's bot account", password => "password" },
    });

For backward compatibility, you can specify up to three parameters:

    my $bot = MediaWiki::Bot->new('My custom useragent string', $assert, $operator);

B<This form is deprecated> will never do auto-login or autoconfiguration, and emits
deprecation warnings.

For further reading:

=over 4

=item *

L<MediaWiki::Bot wiki|https://github.com/MediaWiki-Bot/MediaWiki-Bot/wiki>

=item *

L<<Installing C<MediaWiki::Bot>|https://github.com/MediaWiki-Bot/MediaWiki-Bot/wiki/Install>>

=item *

L<Creating a new bot|https://github.com/MediaWiki-Bot/MediaWiki-Bot/wiki/Creating-a-new-bot>

=item *

L<Setting the wiki|https://github.com/MediaWiki-Bot/MediaWiki-Bot/wiki/Setting-the-wiki>

=item *

L<Where is api.php|https://github.com/MediaWiki-Bot/MediaWiki-Bot/wiki/Where-is-api.php>

=back

=cut

sub new {
    my $package = shift;
    my $agent;
    my $assert;
    my $operator;
    my $maxlag;
    my $protocol;
    my $host;
    my $path;
    my $login_data;
    my $debug;

    if (ref $_[0] eq 'HASH') {
        $agent      = $_[0]->{agent};
        $assert     = $_[0]->{assert};
        $operator   = $_[0]->{operator};
        $maxlag     = $_[0]->{maxlag};
        $protocol   = $_[0]->{protocol};
        $host       = $_[0]->{host};
        $path       = $_[0]->{path};
        $login_data = $_[0]->{login_data};
        $debug      = $_[0]->{debug};
    }
    else {
        warnings::warnif('deprecated', 'Please pass a hashref; this method of calling '
            . 'the constructor is deprecated and will be removed in a future release')
            if @_;
        $agent    = shift;
        $assert   = shift;
        $operator = shift;
        $maxlag   = shift;
        $protocol = shift;
        $host     = shift;
        $path     = shift;
        $debug    = shift;
    }

    $assert   =~ s/[&?]assert=// if $assert; # Strip out param part, leaving just the value
    $operator =~ s/^User://i     if $operator;

    if (not $agent and not $operator) {
        carp q{You should provide either a customized user agent string }
            . q{(see https://meta.wikimedia.org/wiki/User-agent_policy) }
            . q{or provide your username as `operator'.};
    }
    elsif (not $agent and $operator) {
        $operator =~ s{^User:}{};
        $agent = sprintf(
            'Perl MediaWiki::Bot/%s (%s; [[User:%s]])',
            (defined __PACKAGE__->VERSION ? __PACKAGE__->VERSION : 'dev'),
            'https://metacpan.org/MediaWiki::Bot',
            $operator
        );
    }

    my $self = bless({}, $package);
    $self->{errstr}   = '';
    $self->{assert}   = $assert if $assert;
    $self->{operator} = $operator;
    $self->{debug}    = $debug || 0;
    $self->{api}      = MediaWiki::API->new({
        max_lag         => (defined $maxlag ? $maxlag : 5),
        max_lag_delay   => 5,
        max_lag_retries => 5,
        retries         => 5,
        retry_delay     => 10, # no infinite loops
        use_http_get    => 1,  # use HTTP GET to make certain requests cacheable
    });
    $self->{api}->{ua}->agent($agent) if defined $agent;
    $self->{mw_version} = undef; # will be set in get_mw_version

    # Set wiki (handles setting $self->{host} etc)
    $self->set_wiki({
            protocol => $protocol,
            host     => $host,
            path     => $path,
    });

    # Log-in, and maybe autoconfigure
    if ($login_data) {
        my $success = $self->login($login_data);
        if ($success) {
            return $self;
        }
        else {
            carp "Couldn't log in with supplied settings" if $self->{debug};
            return;
        }
    }

    return $self;
}

=head2 set_wiki

Set what wiki to use. The parameter is a hashref with keys:

=over 4

=item *

I<host> - the domain name

=item *

I<path> - the part of the path before api.php (usually 'w')

=item *

I<protocol> is either 'http' or 'https'.

=back

If you don't set any parameter, it's previous value is used. If it has never
been set, the default settings are 'http', 'en.wikipedia.org' and 'w'.

For example:

    $bot->set_wiki({
        protocol    => 'https',
        host        => 'secure.wikimedia.org',
        path        => 'wikipedia/meta/w',
    });

For backward compatibility, you can specify up to two parameters:

    $bot->set_wiki($host, $path);

B<This form is deprecated>, and will emit deprecation warnings.

=cut

sub set_wiki {
    my $self = shift;
    my $host;
    my $path;
    my $protocol;

    if (ref $_[0] eq 'HASH') {
        $host     = $_[0]->{host};
        $path     = $_[0]->{path};
        $protocol = $_[0]->{protocol};
    }
    else {
        warnings::warnif('deprecated', 'Please pass a hashref; this method of calling '
            . 'set_wiki is deprecated, and will be removed in a future release');
        $host = shift;
        $path = shift;
    }

    # Set defaults
    $protocol = $self->{protocol} || 'https'            unless defined($protocol);
    $host     = $self->{host}     || 'en.wikipedia.org' unless defined($host);
    $path     = $self->{path}     || 'w'                unless defined($path);

    # Clean up the parts we will build a URL with
    $protocol =~ s,://$,,;
    if ($host =~ m,^(http|https)(://)?, && !$protocol) {
        $protocol = $1;
    }
    $host =~ s,^https?://,,;
    $host =~ s,/$,,;
    $path =~ s,/$,,;

    # Invalidate wiki-specific cached data
    if (   ((defined($self->{host})) and ($self->{host} ne $host))
        or ((defined($self->{path})) and ($self->{path} ne $path))
        or ((defined($self->{protocol})) and ($self->{protocol} ne $protocol))
    ) {
        delete $self->{ns_data} if $self->{ns_data};
        delete $self->{ns_alias_data} if $self->{ns_alias_data};
    }

    $self->{protocol} = $protocol;
    $self->{host}     = $host;
    $self->{path}     = $path;

    $self->{api}->{config}->{api_url} = $path
        ? "$protocol://$host/$path/api.php"
        : "$protocol://$host/api.php"; # $path is '', so don't use http://domain.com//api.php
    warn "Wiki set to " . $self->{api}->{config}{api_url} . "\n" if $self->{debug} > 1;

    return RET_TRUE;
}

=head2 login

This method takes a hashref with keys I<username> and I<password> at a minimum.
See L</"Single User Login"> and L</"Basic authentication"> for additional options.

Logs the use $username in, optionally using $password. First, an attempt will be
made to use cookies to log in. If this fails, an attempt will be made to use the
password provided to log in, if any. If the login was successful, returns true;
false otherwise.

    $bot->login({
        username => $username,
        password => $password,
    }) or die "Login failed";

Once logged in, attempt to do some simple auto-configuration. At present, this
consists of:

=over 4

=item *

Warning if the account doesn't have the bot flag, and isn't a sysop account.

=item *

Setting an appropriate default assert.

=back

You can skip this autoconfiguration by passing C<autoconfig =E<gt> 0>

For backward compatibility, you can call this as

    $bot->login($username, $password);

B<This form is deprecated>, and will emit deprecation warnings. It will
never do autoconfiguration or SUL login.

=head3 Single User Login

On WMF wikis, C<do_sul> specifies whether to log in on all projects. The default
is false. But even when false, you still get a CentralAuth cookie for, and are
thus logged in on, all languages of a given domain (C<*.wikipedia.org>, for example).
When set, a login is done on each WMF domain so you are logged in on all ~800
content wikis. Since C<*.wikimedia.org> is not possible, we explicitly include
meta, commons, incubator, and wikispecies.

=head3 Basic authentication

If you need to supply basic auth credentials, pass a hashref of data as
described by L<LWP::UserAgent>:

    $bot->login({
        username    => $username,
        password    => $password,
        basic_auth  => {    netloc  => "private.wiki.com:80",
                            realm   => "Authentication Realm",
                            uname   => "Basic auth username",
                            pass    => "password",
                        }
    }) or die "Couldn't log in";

=head3 Bot passwords

C<MediaWiki::Bot> doesn't yet support the more complicated (but more secure)
oAuth login flow for bots. Instead, we support a simpler "bot password", which
is a generated password connected to a (possibly-reduced) set of on-wiki
privileges, and IP ranges from which it can be used.

To create one, visit C<Special:BotPasswords> on the wiki. Enter a label for
the password, then select the privileges you want to use with that password.
This set should be as restricted as possible; most bots only edit existing
pages. Keeping the set of privileges as restricted as possible limits the
possible damage if the password were ever compromised.

Submit the form, and you'll be given a new "username" that looks like
"AccountUsername@bot_password_label", and a generated bot password.
To log in, provide those to C<MediaWiki::Bot> verbatim.

B<References:> L<API:Login|https://www.mediawiki.org/wiki/API:Login>,
L<Logging in|https://github.com/MediaWiki-Bot/MediaWiki-Bot/wiki/Logging-in>

=cut

sub login {
    my $self = shift;
    my $username;
    my $password;
    my $lgdomain;
    my $autoconfig;
    my $basic_auth;
    my $do_sul;
    if (ref $_[0] eq 'HASH') {
        $username   = $_[0]->{username};
        $password   = $_[0]->{password};
        $autoconfig = defined($_[0]->{autoconfig}) ? $_[0]->{autoconfig} : 1;
        $basic_auth = $_[0]->{basic_auth};
        $do_sul     = $_[0]->{do_sul} || 0;
        $lgdomain   = $_[0]->{lgdomain};
    }
    else {
        warnings::warnif('deprecated', 'Please pass a hashref; this method of calling '
            . 'login is deprecated and will be removed in a future release');
        $username   = shift;
        $password   = shift;
        $autoconfig = 0;
        $do_sul     = 0;
    }

    # strip off the "@bot_password_label" suffix, if any
    $self->{username} = (split /@/, $username, 2)[0]; # normal human-readable username
    $self->{login_username} = $username; # to be used for login (includes "@bot_password_label")

    carp "Logging in over plain HTTP is a bad idea, we would be sending secrets"
        . " (passwords or cookies) in plaintext over an insecure connection."
        . " To protect against eavesdroppers, set protocol => 'https'"
        unless $self->{protocol} eq 'https';

    # Handle basic auth first, if needed
    if ($basic_auth) {
        warn 'Applying basic auth credentials' if $self->{debug} > 1;
        $self->{api}->{ua}->credentials(
            $basic_auth->{netloc},
            $basic_auth->{realm},
            $basic_auth->{uname},
            $basic_auth->{pass}
        );
    }

    if ($self->{host} eq 'secure.wikimedia.org') {
        warnings::warnif('deprecated', 'SSL is now supported on the main Wikimedia Foundation sites. '
            . 'Use en.wikipedia.org (or whatever) instead of secure.wikimedia.org.');
        return;
    }

    if($do_sul) {
        my $sul_success = $self->_do_sul($password);
        warn 'Some or all SUL logins failed' if $self->{debug} > 1 and !$sul_success;
    }

    my $cookies = ".mediawiki-bot-$username-cookies";
    if (-r $cookies) {
        $self->{api}->{ua}->{cookie_jar}->load($cookies);
        $self->{api}->{ua}->{cookie_jar}->{ignore_discard} = 1;
        # $self->{api}->{ua}->add_handler("request_send", sub { shift->dump; return });

        if ($self->_is_loggedin()) {
            $self->_do_autoconfig() if $autoconfig;
            warn 'Logged in successfully with cookies' if $self->{debug} > 1;
            return 1; # If we're already logged in, nothing more is needed
        }
    }

    unless ($password) {
        carp q{Cookies didn't get us logged in, and no password to continue with authentication} if $self->{debug};
        return;
    }

    my $res;
    RETRY: for (1..2) {
        # Fetch a login token
        $res = $self->{api}->api({
            action  => 'query',
            meta    => 'tokens',
            type    => 'login',
        }) or return $self->_handle_api_error();
        my $token = $res->{query}->{tokens}->{logintoken};

        # Do the login
        $res = $self->{api}->api({
            action      => 'login',
            lgname      => $self->{login_username},
            lgpassword  => $password,
            lgdomain    => $lgdomain,
            lgtoken     => $token,
        }) or return $self->_handle_api_error();

        last RETRY if $res->{login}->{result} eq 'Success';
    };

    $self->{api}->{ua}->{cookie_jar}->extract_cookies($self->{api}->{response});
    $self->{api}->{ua}->{cookie_jar}->save($cookies) if (-w($cookies) or -w('.'));

    if ($res->{login}->{result} eq 'Success') {
        if ($res->{login}->{lgusername} eq $self->{username}) {
            $self->_do_autoconfig() if $autoconfig;
            warn 'Logged in successfully with password' if $self->{debug} > 1;
        }
    }

    return ((defined($res->{login}->{lgusername})) and
            (defined($res->{login}->{result})) and
            ($res->{login}->{lgusername} eq $self->{username}) and
            ($res->{login}->{result} eq 'Success'));
}

sub _do_sul {
    my $self     = shift;
    my $password = shift;
    my $debug    = $self->{debug};  # Remember these for later
    my $host     = $self->{host};
    my $path     = $self->{path};
    my $protocol = $self->{protocol};
    my $username = $self->{login_username};

    $self->{debug} = 0;             # Turn off debugging for these internal calls
    my @logins;                     # Keep track of our successes
    my @WMF_projects = qw(
        en.wikipedia.org
        en.wiktionary.org
        en.wikibooks.org
        en.wikinews.org
        en.wikiquote.org
        en.wikisource.org
        en.wikiversity.org
        meta.wikimedia.org
        commons.wikimedia.org
        species.wikimedia.org
        incubator.wikimedia.org
    );

    SUL: foreach my $project (@WMF_projects) { # Could maybe be parallelized
        print STDERR "Logging in on $project..." if $debug > 1;
        $self->set_wiki({
            host    => $project,
        });
        my $success = $self->login({
            username    => $username,
            password    => $password,
            do_sul      => 0,
            autoconfig  => 0,
        });
        warn ($success ? " OK\n" : " FAILED:\n") if $debug > 1;
        warn $self->{api}->{error}->{code} . ': ' . $self->{api}->{error}->{details}
            if $debug > 1 and !$success;
        push(@logins, $success);
    }
    $self->set_wiki({           # Switch back to original wiki
        protocol => $protocol,
        host     => $host,
        path     => $path,
    });

    my $sum = sum 0, @logins;
    my $total = scalar @WMF_projects;
    warn "$sum/$total logins succeeded" if $debug > 1;
    $self->{debug} = $debug; # Reset debug to it's old value

    return $sum == $total;
}

=head2 logout

    $bot->logout();

The logout method logs the bot out of the wiki. This invalidates all login
cookies.

B<References:> L<API:Logging out|https://www.mediawiki.org/wiki/API:Logout>

=cut

sub logout {
    my $self = shift;

    $self->{api}->api({ action => 'logout' });
    return RET_TRUE;
}

=head2 edit

    my $text = $bot->get_text('My page');
    $text .= "\n\n* More text\n";
    $bot->edit({
        page    => 'My page',
        text    => $text,
        summary => 'Adding new content',
        section => 'new',
    });

This method edits a wiki page, and takes a hashref of data with keys:

=over 4

=item *

I<page> - the page title to edit

=item *

I<text> - the page text to write

=item *

I<summary> - an edit summary

=item *

I<minor> - whether to mark the edit as minor or not (boolean)

=item *

I<bot> - whether to mark the edit as a bot edit (boolean)

=item *

I<assertion> - usually 'bot', but see L<http://mediawiki.org/wiki/Extension:AssertEdit>.

=item *

I<section> - edit a single section (identified by number) instead of the whole page

=back

An MD5 hash is sent to guard against data corruption while in transit.

You can also call this as:

    $bot->edit($page, $text, $summary, $is_minor, $assert, $markasbot);

B<This form is deprecated>, and will emit deprecation warnings.

=head3 CAPTCHAs

If a L<CAPTCHA|https://en.wikipedia.org/wiki/CAPTCHA> is encountered, the
call to C<edit> will return false, with the error code set to C<ERR_CAPTCHA>
and the details informing you that solving a CAPTCHA is required for this
action. The information you need to actually solve the captcha (for example
the URL for the image) is given in C<< $bot->{error}->{captcha} >> as a
hash reference. You will want to grab the keys 'url' (a relative URL to
the image) and 'id' (the ID of the CAPTCHA). Once you have solved the
CAPTCHA (presumably by interacting with a human), retry the edit, adding
C<captcha_id> and C<captcha_solution> parameters:

    my $edit = {page => 'Main Page', text => 'got your nose'};
    my $edit_status = $bot->edit($edit);
    if (not $edit_status) {
        if ($bot->{error}->{code} == ERR_CAPTCHA) {
            my @captcha_uri = split /\Q?/, $bot->{error}{captcha}{url}, 2;
            my $image = URI->new(sprintf '%s://%s%s?%s' =>
                $bot->{protocol}, $bot->{host}, $captcha_uri[0], $captcha_uri[1],
            );

            require Term::ReadLine;
            my $term = Term::ReadLine->new('Solve the captcha');
            $term->ornaments(0);
            my $answer = $term->readline("Please solve $image and type the answer: ");

            # Add new CAPTCHA params to the edit we're attempting
            $edit->{captcha_id} = $bot->{error}->{captcha}->{id};
            $edit->{captcha_solution} = $answer;
            $status = $bot->edit($edit);
        }
    }

B<References:> L<Editing pages|https://github.com/MediaWiki-Bot/MediaWiki-Bot/wiki/Editing-pages>,
L<API:Edit|https://www.mediawiki.org/wiki/API:Edit>,
L<API:Tokens|https://www.mediawiki.org/wiki/API:Tokens>

=cut

sub edit {
    my $self = shift;
    my $page;
    my $text;
    my $summary;
    my $is_minor;
    my $assert;
    my $markasbot;
    my $section;
    my $captcha_id;
    my $captcha_solution;

    if (ref $_[0] eq 'HASH') {
        $page      = $_[0]->{page};
        $text      = $_[0]->{text};
        $summary   = $_[0]->{summary};
        $is_minor  = $_[0]->{minor};
        $assert    = $_[0]->{assert};
        $markasbot = $_[0]->{markasbot};
        $section   = $_[0]->{section};
        $captcha_id         = $_[0]->{captcha_id};
        $captcha_solution   = $_[0]->{captcha_solution};
    }
    else {
        warnings::warnif('deprecated', 'Please pass a hashref; this method of calling '
            . 'edit is deprecated, and will be removed in a future release.');
        $page      = shift;
        $text      = shift;
        $summary   = shift;
        $is_minor  = shift;
        $assert    = shift;
        $markasbot = shift;
        $section   = shift;
    }

    # Set defaults
    $summary = 'BOT: Changing page text' unless $summary;
    if ($assert) {
        $assert =~ s/^[&?]assert=//;
    }
    else {
        $assert = $self->{assert};
    }
    $is_minor  = 1 unless defined($is_minor);
    $markasbot = 1 unless defined($markasbot);

    # Clear any captcha data that might remain from a previous edit attempt
    delete $self->{error}->{captcha};
    carp 'Need both captcha_id and captcha_solution when editing with a solved CAPTCHA'
        if (defined $captcha_id and not defined $captcha_solution)
        or (defined $captcha_solution and not defined $captcha_id);

    my ($edittoken, $lastedit, $tokentime) = $self->_get_edittoken($page);
    return $self->_handle_api_error() unless $edittoken;

    # HTTP::Message will do this eventually as of 6.03  (RT#75592), so we need
    # to do it here - otherwise, the md5 won't match what eventually is sent to
    # the server, and the edit will fail - GH#39.
    # If HTTP::Message becomes unbroken in the future, might have to keep this
    # workaround for people using 6.03 and other future broken versions.
    $text =~ s{(?<!\r)\n}{\r\n}g;
    my $md5 = md5_hex(encode_utf8($text)); # Pass only bytes to md5_hex()
    my $hash = {
        action         => 'edit',
        title          => $page,
        token          => $edittoken,
        text           => $text,
        md5            => $md5,             # Guard against data corruption
        summary        => $summary,
        basetimestamp  => $lastedit,        # Guard against edit conflicts
        starttimestamp => $tokentime,       # Guard against the page being deleted/moved
        bot            => $markasbot,
        ( $section  ? (section => $section) : ()),
        ( $assert   ? (assert => $assert)   : ()),
        ( $is_minor ? (minor => 1)          : (notminor => 1)),
        ( $captcha_id ? (captchaid => $captcha_id) : ()),
        ( $captcha_solution ? (captchaword => $captcha_solution) : ()),
    };

    ### Actually do the edit
    my $res = $self->{api}->api($hash);
    return $self->_handle_api_error() unless $res;

    if ($res->{edit}->{result} && $res->{edit}->{result} eq 'Failure') {
        # https://www.mediawiki.org/wiki/API:Edit#CAPTCHAs_and_extension_errors
        # You need to solve the CAPTCHA, then retry the request with the ID in
        # this error response and the solution.
        if (exists $res->{edit}->{captcha}) {
            return $self->_handle_api_error({
                code => ERR_CAPTCHA,
                details => 'captcharequired: This action requires that a CAPTCHA be solved',
                captcha => $res->{edit}->{captcha},
            });
        }
        return $self->_handle_api_error();
    }

    return $res;
}

=head2 move

    $bot->move($from_title, $to_title, $reason, $options_hashref);

This moves a wiki page.

If you wish to specify more options (like whether to suppress creation of a
redirect), use $options_hashref, which has keys:

=over 4

=item *

I<movetalk> specifies whether to attempt to the talk page.

=item *

I<noredirect> specifies whether to suppress creation of a redirect.

=item *

I<movesubpages> specifies whether to move subpages, if applicable.

=item *

I<watch> and I<unwatch> add or remove the page and the redirect from your watchlist.

=item *

I<ignorewarnings> ignores warnings.

=back

    my @pages = ("Humor", "Rumor");
    foreach my $page (@pages) {
        my $to = $page;
        $to =~ s/or$/our/;
        $bot->move($page, $to, "silly 'merricans");
    }

B<References:> L<API:Move|https://www.mediawiki.org/wiki/API:Move>

=cut

sub move {
    my $self   = shift;
    my $from   = shift;
    my $to     = shift;
    my $reason = shift;
    my $opts   = shift;

    my $hash = {
        action => 'move',
        from   => $from,
        to     => $to,
        reason => $reason,
    };
    $hash->{movetalk}     = $opts->{movetalk}     if defined($opts->{movetalk});
    $hash->{noredirect}   = $opts->{noredirect}   if defined($opts->{noredirect});
    $hash->{movesubpages} = $opts->{movesubpages} if defined($opts->{movesubpages});

    my $res = $self->{api}->edit($hash);
    return $self->_handle_api_error() unless $res;
    return $res; # should we return something more useful?
}

=head2 get_history

    my @hist = $bot->get_history($title);
    my @hist = $bot->get_history($title, $additional_params);

Returns an array containing the history of the specified page $title.

The optional hash ref $additional_params can be used to tune the
query by API parameters,
such as 'rvlimit' to return only 'rvlimit' number of revisions (default is as many
as possible, but may be limited per query) or 'rvdir' to set the chronological
direction.

Example:

    my @hist = $bot->get_history('Main Page', {'rvlimit' => 10, 'rvdir' => 'older'})

The array returned contains hashrefs with keys: revid, user, comment, minor,
timestamp_date, and timestamp_time.

For backward compatibility, you can specify up to four parameters:

    my @hist = $bot->get_history($title, $limit, $revid, $direction);

B<References>: L<Getting page history|https://github.com/MediaWiki-Bot/MediaWiki-Bot/wiki/Getting-page-history>,
L<API:Properties#revisions|https://www.mediawiki.org/wiki/API:Properties#revisions_.2F_rv>

=cut

sub get_history {
    my $self      = shift;
    my $pagename  = shift;
    my $additional_params = shift;
    # for backward-compatibility check for textual params
    if(ref $additional_params eq '' ){
        if(@_ > 0 || defined $additional_params){
            warnings::warnif('deprecated', 'Please pass a hashref; this method of calling '
                . 'get_history is deprecated and will be removed in a future release');
            my $rvlimit = $additional_params;
            my $rvstartid = shift;
            my $rvdir = shift;
            $additional_params = {};
            $additional_params->{'rvlimit'} = $rvlimit if $rvlimit;
            $additional_params->{'rvstartid'} = $rvstartid if $rvstartid;
            $additional_params->{'rvdir'} = $rvdir if $rvdir;
        }else{
            $additional_params = {};
        }
    }
    my $ready;
    my $filter_params = {%$additional_params};
    my @full_hist;
    while(!$ready){
        my @hist = $self->get_history_step_by_step($pagename, $filter_params);
        if(@hist == 0 || !defined($filter_params->{'continue'})){
            $ready = 1;
        }
        push @full_hist, @hist;
    }
    return @full_hist;
}

=head2 get_history_step_by_step

    my @hist = $bot->get_history_step_by_step($title);
    my @hist = $bot->get_history_step_by_step($title, $additional_params);

Same as get_history(), but does not return the full history at once, but let's you
loop through it.

The optional call-by-reference hash ref $additional_params can be used to loop
through a page's full history by using the 'continue' param returned by the API.

Example:

    my $ready;
    my $filter_params = {};
    while(!$ready){
        my @hist = $bot->get_history_step_by_step($page, $filter_params);
        if(@hist == 0 || !defined($filter_params->{'continue'})){
            $ready = 1;
        }
        # do something with @hist
    }

B<References>: L<Getting page history|https://github.com/MediaWiki-Bot/MediaWiki-Bot/wiki/Getting-page-history>,
L<API:Properties#revisions|https://www.mediawiki.org/wiki/API:Properties#revisions_.2F_rv>

=cut

sub get_history_step_by_step {
    my $self      = shift;
    my $pagename  = shift;
    my $additional_params = shift // {};
    my $query = {
        action  => 'query',
        prop    => 'revisions',
        titles  => $pagename,
        rvprop  => 'ids|timestamp|user|comment|flags',
    };
    while(my ($key, $value) = each %$additional_params){
      $query->{$key} = $value;
    }
    $query->{'rvlimit'} = 'max' unless defined $query->{'rvlimit'};

    my $res = $self->{api}->api($query);
    return $self->_handle_api_error() unless $res;
    my ($id) = keys %{ $res->{query}->{pages} };
    my $array = $res->{query}->{pages}->{$id}->{revisions};

    my @return;
    for my $hash (@{$array}) {
        my $revid = $hash->{revid};
        my $user  = $hash->{user};
        my ($timestamp_date, $timestamp_time) = split(/T/, $hash->{timestamp});
        $timestamp_time =~ s/Z$//;
        my $comment = $hash->{comment};
        push(
            @return,
            {
                revid          => $revid,
                user           => $user,
                timestamp_date => $timestamp_date,
                timestamp_time => $timestamp_time,
                comment        => $comment,
                minor          => exists $hash->{minor},
            });
    }
    $additional_params->{'continue'} = $res->{'continue'}{'continue'};
    $additional_params->{'rvcontinue'} = $res->{'continue'}{'rvcontinue'};
    return @return;
}

=head2 get_text

Returns the wikitext of the specified $page_title.
The first parameter $page_title is the only required one.

The second parameter is a hashref with the following independent optional keys:

=over 4

=item *

C<rvstartid> - if defined, this function returns the text of that revision, otherwise
the newest revision will be used.

=item *

C<rvsection> - if defined, returns the text of that section. Otherwise the
whole page text will be returned.

=item *

C<pageid> - this is an output parameter and can be used to fetch the id of a page
without the need of calling L</get_id> additionally. Note that the value of this
param is ignored and it will be overwritten by this function.

=item *

C<rv...> - any param starting with 'rv' will be forwarded to the api call.

=back

A blank page will return wikitext of "" (which evaluates to false in Perl,
but is defined); a nonexistent page will return undef (which also evaluates
to false in Perl, but is obviously undefined). You can distinguish between
blank and nonexistent pages by using L<defined|perlfunc/defined>:

    # simple example
    my $wikitext = $bot->get_text('Page title');
    print "Wikitext: $wikitext\n" if defined $wikitext;

    # advanced example
    my $options = {'revid'=>123456, 'section_number'=>2};
    $wikitext = $bot->get_text('Page title', $options);
    die "error, see API error message\n" unless defined $options->{'pageid'};
    warn "page doesn't exist\n" if $options->{'pageid'} == MediaWiki::Bot::PAGE_NONEXISTENT;
    print "Wikitext: $wikitext\n" if defined $wikitext;

B<References:> L<Fetching page text|https://github.com/MediaWiki-Bot/MediaWiki-Bot/wiki/Fetching-page-text>,
L<API:Properties#revisions|https://www.mediawiki.org/wiki/API:Properties#revisions_.2F_rv>

For backward-compatibility the params C<revid> and C<section_number> may also be
given as scalar parameters:

    my $wikitext = $bot->get_text('Page title', 123456, 2);
    print "Wikitext: $wikitext\n" if defined $wikitext;

=cut

sub get_text {
    my $self     = shift;
    my $pagename = shift;
    unless(defined $pagename){
        warn "get_text(): param \$pagename is not defined.\n" if $self->{'debug'} > 1;
        return;
    }
    my $options  = shift;
    # for backward-compatibility: try to read scalars
    if(ref $options eq ''){
        if(@_ > 0 || defined $options){
            warnings::warnif('deprecated', 'Please pass a hashref; this method of calling '
                . 'get_text is deprecated and will be removed in a future release');
            $options = {
                'rvstartid' => $options,
                'rvsection' => shift,
            };
            delete $options->{'rvstartid'} unless defined $options->{'rvstartid'};
            delete $options->{'rvsection'} unless defined $options->{'rvsection'};
        }else{
            $options = {};
        }
    }

    my $hash = {
        action => 'query',
        titles => $pagename,
        prop   => 'revisions',
        rvprop => 'content',
    };
    for my $key(keys %$options){
        if(substr($key, 0, 2) eq 'rv'){
            $hash->{$key} = $options->{$key};
        }
    }
    my $res = $self->{api}->api($hash);
    return $self->_handle_api_error() unless $res;
    ($options->{'pageid'}, my $data) = %{ $res->{query}->{pages} };

    return if $options->{'pageid'} == PAGE_NONEXISTENT;
    return $data->{revisions}[0]->{'*'}; # the wikitext
}

=head2 get_id

Returns the id of the specified $page_title. Returns undef if page does not exist.

    my $pageid = $bot->get_id("Main Page");
    die "Page doesn't exist\n" if !defined($pageid);

B<Revisions:> L<API:Properties#info|https://www.mediawiki.org/wiki/API:Properties#info_.2F_in>

=cut

sub get_id {
    my $self     = shift;
    my $pagename = shift;

    my $hash = {
        action => 'query',
        titles => $pagename,
    };

    my $res = $self->{api}->api($hash);
    return $self->_handle_api_error() unless $res;
    my ($id) = %{ $res->{query}->{pages} };
    return if $id == PAGE_NONEXISTENT;
    return $id;
}

=head2 get_pages

Returns the text of the specified pages in a hashref. Content of undef means
page does not exist. Also handles redirects or article names that use namespace
aliases.

    my @pages = ('Page 1', 'Page 2', 'Page 3');
    my $thing = $bot->get_pages(\@pages);
    foreach my $page (keys %$thing) {
        my $text = $thing->{$page};
        print "$text\n" if defined($text);
    }

B<References:> L<Fetching page text|https://github.com/MediaWiki-Bot/MediaWiki-Bot/wiki/Fetching-page-text>,
L<API:Properties#revisions|https://www.mediawiki.org/wiki/API:Properties#revisions_.2F_rv>

=cut

sub get_pages {
    my $self  = shift;
    my @pages = (ref $_[0] eq 'ARRAY') ? @{$_[0]} : @_;
    my %return;

    my $hash = {
        action => 'query',
        titles => join('|', @pages),
        prop   => 'revisions',
        rvprop => 'content',
    };

    my $diff;    # Used to track problematic article names
    map { $diff->{$_} = 1; } @pages;

    my $res = $self->{api}->api($hash);
    return $self->_handle_api_error() unless $res;

    foreach my $id (keys %{ $res->{query}->{pages} }) {
        my $page = $res->{query}->{pages}->{$id};
        if ($diff->{ $page->{title} }) {
            $diff->{ $page->{title} }++;
        }
        else {
            next;
        }

        if (defined($page->{missing})) {
            $return{ $page->{title} } = undef;
            next;
        }
        if (defined($page->{revisions})) {
            my $revisions = @{ $page->{revisions} }[0]->{'*'};
            if (!defined $revisions) {
                $return{ $page->{title} } = $revisions;
            }
            elsif (length($revisions) < 150 && $revisions =~ m/\#REDIRECT\s\[\[([^\[\]]+)\]\]/) {    # FRAGILE!
                my $redirect_to = $1;
                $return{ $page->{title} } = $self->get_text($redirect_to);
            }
            else {
                $return{ $page->{title} } = $revisions;
            }
        }
    }

    my $expand = $self->_get_ns_alias_data();
    # Only for those article names that remained after the first part
    # If we're here we are dealing most likely with a WP:CSD type of article name
    for my $title (keys %$diff) {
        if ($diff->{$title} == 1) {
            my @pieces = split(/:/, $title);
            if (@pieces > 1) {
                $pieces[0] = ($expand->{ $pieces[0] } || $pieces[0]);
                my $v = $self->get_text(join ':', @pieces);
                warn "Detected article name that needed expanding $title\n" if $self->{debug} > 1;

                $return{$title} = $v;
                if (defined $v and $v =~ m/\#REDIRECT\s\[\[([^\[\]]+)\]\]/) {
                    $v = $self->get_text($1);
                    $return{$title} = $v;
                }
            }
        }
    }
    return \%return;
}

=head2 get_image

    $buffer = $bot->get_image('File:Foo.jpg', { width=>256, height=>256 });

Download an image from a wiki. This is derived from a similar function in
L<MediaWiki::API>. This one allows the image to be scaled down by passing a hashref
with height & width parameters.

It returns raw data in the original format. You may simply spew it to a file, or
process it directly with a library such as L<Imager>.

    use File::Slurp qw(write_file);
    my $img_data = $bot->get_image('File:Foo.jpg');
    write_file( 'Foo.jpg', {binmode => ':raw'}, \$img_data );

Images are scaled proportionally. (height/width) will remain
constant, except for rounding errors.

Height and width parameters describe the B<maximum> dimensions. A 400x200
image will never be scaled to greater dimensions. You can scale it yourself;
having the wiki do it is just lazy & selfish.

B<References:> L<API:Properties#imageinfo|https://www.mediawiki.org/wiki/API:Properties#imageinfo_.2F_ii>

=cut

sub get_image{
    my $self = shift;
    my $name = shift;
    my $options = shift;

    my %sizeparams;
    $sizeparams{iiurlwidth} = $options->{width} if $options->{width};
    $sizeparams{iiurlheight} = $options->{height} if $options->{height};

    my $ref = $self->{api}->api({
          action => 'query',
          titles => $name,
          prop   => 'imageinfo',
          iiprop => 'url|size',
          %sizeparams
    });
    return $self->_handle_api_error() unless $ref;
    my ($pageref) = values %{ $ref->{query}->{pages} };
    return unless defined $pageref->{imageinfo}; # if the image is missing

    my $url = @{ $pageref->{imageinfo} }[0]->{thumburl} || @{ $pageref->{imageinfo} }[0]->{url};
    die "$url should be absolute or something." unless ( $url =~ m{^https?://} );

    my $response = $self->{api}->{ua}->get($url);
    return $self->_handle_api_error() unless ( $response->code == 200 );
    return $response->decoded_content;
}

=head2 revert

Reverts the specified $page_title to $revid, with an edit summary of $summary. A
default edit summary will be used if $summary is omitted.

    my $revid = $bot->get_last("User:Mike.lifeguard/sandbox", "Mike.lifeguard");
    print "Reverting to $revid\n" if defined($revid);
    $bot->revert('User:Mike.lifeguard', $revid, 'rvv');

B<References:> L<API:Edit|https://www.mediawiki.org/wiki/API:Edit>

=cut

sub revert {
    my $self     = shift;
    my $pagename = shift;
    my $revid    = shift;
    my $summary  = shift || "Reverting to old revision $revid";

    my $text = $self->get_text($pagename, $revid);
    my $res = $self->edit({
        page    => $pagename,
        text    => $text,
        summary => $summary,
    });

    return $res;
}

=head2 undo

    $bot->undo($title, $revid, $summary, $after);

Reverts the specified $revid, with an edit summary of $summary, using the undo
function. To undo all revisions from $revid up to but not including this one,
set $after to another revid. If not set, just undo the one revision ($revid).

B<References:> L<API:Edit|https://www.mediawiki.org/wiki/API:Edit>

=cut

sub undo {
    my $self    = shift;
    my $page    = shift;
    my $revid   = shift || croak "No revid given";
    my $summary = shift || "Reverting revision #$revid";
    my $after   = shift;
    $summary = "Reverting edits between #$revid & #$after" if defined($after);    # Is that clear? Correct?

    my ($edittoken, $basetimestamp, $starttimestamp) = $self->_get_edittoken($page);
    my $hash = {
        action         => 'edit',
        title          => $page,
        undo           => $revid,
        (undoafter     => $after)x!! defined $after,
        summary        => $summary,
        token          => $edittoken,
        starttimestamp => $starttimestamp,
        basetimestamp  => $basetimestamp,
    };

    my $res = $self->{api}->api($hash);
    return $self->_handle_api_error() unless $res;
    return $res;
}

=head2 get_last

Returns the revid of the last revision to $page not made by $user. undef is
returned if no result was found, as would be the case if the page is deleted.

    my $revid = $bot->get_last('User:Mike.lifeguard/sandbox', 'Mike.lifeguard');
    if defined($revid) {
        print "Reverting to $revid\n";
        $bot->revert('User:Mike.lifeguard', $revid, 'rvv');
    }

B<References:> L<API:Properties#revisions|https://www.mediawiki.org/wiki/API:Properties#revisions_.2F_rv>

=cut

sub get_last {
    my $self = shift;
    my $page = shift;
    my $user = shift;

    my $res = $self->{api}->api({
            action        => 'query',
            titles        => $page,
            prop          => 'revisions',
            rvlimit       => 1,
            rvprop        => 'ids|user',
            rvexcludeuser => $user || '',
    });
    return $self->_handle_api_error() unless $res;

    my (undef, $data) = %{ $res->{query}->{pages} };
    my $revid = $data->{revisions}[0]->{revid};
    return $revid;
}

=head2 update_rc

B<This method is deprecated>, and will emit deprecation warnings.
Replace calls to C<update_rc()> with calls to the newer C<recentchanges()>, which
returns all available data, including rcid.

Returns an array containing the $limit most recent changes to the wiki's I<main
namespace>. The array contains hashrefs with keys title, revid, old_revid,
and timestamp.

    my @rc = $bot->update_rc(5);
    foreach my $hashref (@rc) {
        my $title = $hash->{'title'};
        print "$title\n";
    }

The L</"Options hashref"> is also available:

    # Use a callback for incremental processing:
    my $options = { hook => \&mysub, };
    $bot->update_rc($options);
    sub mysub {
        my ($res) = @_;
        foreach my $hashref (@$res) {
            my $page = $hashref->{'title'};
            print "$page\n";
        }
    }

=cut

sub update_rc {
    warnings::warnif('deprecated', 'update_rc is deprecated, and may be removed '
        . 'in a future release. Please use recentchanges(), which provides more '
        . 'data, including rcid');
    my $self    = shift;
    my $limit   = shift || 'max';
    my $options = shift;

    my $hash = {
        action      => 'query',
        list        => 'recentchanges',
        rcnamespace => 0,
        rclimit     => $limit,
    };
    $options->{max} = 1 unless $options->{max};

    my $res = $self->{api}->list($hash, $options);
    return $self->_handle_api_error() unless $res;
    return RET_TRUE if not ref $res; # Not a ref when using callback

    my @rc_table;
    foreach my $hash (@{$res}) {
        push(
            @rc_table,
            {
                title     => $hash->{title},
                revid     => $hash->{revid},
                old_revid => $hash->{old_revid},
                timestamp => $hash->{timestamp},
            }
        );
    }
    return @rc_table;
}

=head2 recentchanges($wiki_hashref, $options_hashref)

Returns an array of hashrefs containing recentchanges data.

The first parameter is a hashref with the following keys:

=over 4

=item *

I<ns> - the namespace number, or an arrayref of numbers to
specify several; default is the main namespace

=item *

I<limit> - the number of rows to fetch; default is 50

=item *

I<user> - only list changes by this user

=item *

I<show> - itself a hashref where the key is a category and the value is
a boolean. If true, the category will be included; if false, excluded. The
categories are kinds of edits: minor, bot, anon, redirect, patrolled. See
"rcshow" at L<http://www.mediawiki.org/wiki/API:Recentchanges#Parameters>.

=back

An L</"Options hashref"> can be used as the second parameter:

    my @rc = $bot->recentchanges({ ns => 4, limit => 100 });
    foreach my $hashref (@rc) {
        print $hashref->{title} . "\n";
    }

    # Or, use a callback for incremental processing:
    $bot->recentchanges({ ns => [0,1], limit => 500 }, { hook => \&mysub });
    sub mysub {
        my ($res) = @_;
        foreach my $hashref (@$res) {
            my $page = $hashref->{title};
            print "$page\n";
        }
    }

The hashref returned might contain the following keys:

=over 4

=item *

I<ns> - the namespace number

=item *

I<revid>

=item *

I<old_revid>

=item *

I<timestamp>

=item *

I<rcid> - can be used with L</patrol>

=item *

I<pageid>

=item *

I<type> - one of edit, new, log (there may be others)

=item *

I<title>

=back

For backwards compatibility, the previous method signature is still
supported:

    $bot->recentchanges($ns, $limit, $options_hashref);

B<References:> L<API:Recentchanges|https://www.mediawiki.org/wiki/API:Recentchanges>

=cut

sub recentchanges {
    my $self = shift;
    my $ns;
    my $limit;
    my $options;
    my $user;
    my $show;
    if (ref $_[0] eq 'HASH') { # unpack for new args
        my %args = %{ +shift };
        $ns     = delete $args{ns};
        $limit  = delete $args{limit};
        $user   = delete $args{user};

        if (ref $args{show} eq 'HASH') {
            my @show;
            while (my ($k, $v) = each %{ $args{show} }) {
                push @show, '!'x!$v . $k;
            }
            $show = join '|', @show;
        }
        else {
            $show = delete $args{show};
        }

        $options = shift;
    }
    else {
        $ns      = shift || 0;
        $limit   = shift || 50;
        $options = shift;
    }
    $ns = join('|', @$ns) if ref $ns eq 'ARRAY';

    my $hash = {
        action      => 'query',
        list        => 'recentchanges',
        rcnamespace => $ns,
        rclimit     => $limit,
        rcprop      => 'user|comment|timestamp|title|ids',
    };
    $hash->{rcuser} = $user if defined $user;
    $hash->{rcshow} = $show if defined $show;

    $options->{max} = 1 unless $options->{max};

    my $res = $self->{api}->list($hash, $options)
        or return $self->_handle_api_error();
    return RET_TRUE unless ref $res; # Not a ref when using callback
    return @$res;
}

=head2 what_links_here

Returns an array containing a list of all pages linking to $page.

Additional optional parameters are:

=over 4

=item *

One of: all (default), redirects, or nonredirects.

=item *

A namespace number to search (pass an arrayref to search in multiple namespaces)

=item *

An L</"Options hashref">.

=back

A typical query:

    my @links = $bot->what_links_here("Meta:Sandbox",
        undef, 1,
        { hook=>\&mysub }
    );
    sub mysub{
        my ($res) = @_;
        foreach my $hash (@$res) {
            my $title = $hash->{'title'};
            my $is_redir = $hash->{'redirect'};
            print "Redirect: $title\n" if $is_redir;
            print "Page: $title\n" unless $is_redir;
        }
    }

Transclusions are no longer handled by what_links_here() - use
L</list_transclusions> instead.

B<References:> L<Listing incoming links|https://github.com/MediaWiki-Bot/MediaWiki-Bot/wiki/Listing-incoming-links>,
L<API:Backlinks|https://www.mediawiki.org/wiki/API:Backlinks>

=cut

sub what_links_here {
    my $self    = shift;
    my $page    = shift;
    my $filter  = shift;
    my $ns      = shift;
    my $options = shift;

    $ns = join('|', @$ns) if (ref $ns eq 'ARRAY');    # Allow array of namespaces
    if (defined($filter) and $filter =~ m/(all|redirects|nonredirects)/) {    # Verify $filter
        $filter = $1;
    }

    # http://en.wikipedia.org/w/api.php?action=query&list=backlinks&bltitle=template:tlx
    my $hash = {
        action      => 'query',
        list        => 'backlinks',
        bltitle     => $page,
        bllimit     => 'max',
    };
    $hash->{blnamespace}   = $ns if defined $ns;
    $hash->{blfilterredir} = $filter if $filter;
    $options->{max} = 1 unless $options->{max};

    my $res = $self->{api}->list($hash, $options);
    return $self->_handle_api_error() unless $res;
    return RET_TRUE if not ref $res; # When using a callback hook, this won't be a reference
    my @links;
    foreach my $hashref (@$res) {
        my $title    = $hashref->{title};
        my $redirect = defined($hashref->{redirect});
        push @links, { title => $title, redirect => $redirect };
    }

    return @links;
}

=head2 list_transclusions

Returns an array containing a list of all pages transcluding $page.

Other parameters are:

=over 4

=item *

One of: all (default), redirects, or nonredirects

=item *

A namespace number to search (pass an arrayref to search in multiple namespaces).

=item *

$options_hashref as described by L<MediaWiki::API>:

Set max to limit the number of queries performed.

Set hook to a subroutine reference to use a callback hook for incremental
processing.

Refer to the section on L</linksearch> for examples.

=back

A typical query:

    $bot->list_transclusions("Template:Tlx", undef, 4, {hook => \&mysub});
    sub mysub{
        my ($res) = @_;
        foreach my $hash (@$res) {
            my $title = $hash->{'title'};
            my $is_redir = $hash->{'redirect'};
            print "Redirect: $title\n" if $is_redir;
            print "Page: $title\n" unless $is_redir;
        }
    }

B<References:> L<Listing transclusions|https://github.com/MediaWiki-Bot/MediaWiki-Bot/wiki/Listing-transclusions>
L<API:Embeddedin|https://www.mediawiki.org/wiki/API:Embeddedin>

=cut

sub list_transclusions {
    my $self    = shift;
    my $page    = shift;
    my $filter  = shift;
    my $ns      = shift;
    my $options = shift;

    $ns = join('|', @$ns) if (ref $ns eq 'ARRAY');
    if (defined($filter) and $filter =~ m/(all|redirects|nonredirects)/) {    # Verify $filter
        $filter = $1;
    }

    # http://en.wikipedia.org/w/api.php?action=query&list=embeddedin&eititle=Template:Stub
    my $hash = {
        action      => 'query',
        list        => 'embeddedin',
        eititle     => $page,
        eilimit     => 'max',
    };
    $hash->{eifilterredir} = $filter if $filter;
    $hash->{einamespace}   = $ns if defined $ns;
    $options->{max} = 1 unless $options->{max};

    my $res = $self->{api}->list($hash, $options);
    return $self->_handle_api_error() unless $res;
    return RET_TRUE if not ref $res; # When using a callback hook, this won't be a reference
    my @links;
    foreach my $hashref (@$res) {
        my $title    = $hashref->{title};
        my $redirect = defined($hashref->{redirect});
        push @links, { title => $title, redirect => $redirect };
    }

    return @links;
}

=head2 get_pages_in_category

Returns an array containing the names of all pages in the specified category
(include the Category: prefix). Does not recurse into sub-categories.

    my @pages = $bot->get_pages_in_category('Category:People on stamps of Gabon');
    print "The pages in Category:People on stamps of Gabon are:\n@pages\n";

The options hashref is as described in L</"Options hashref">.
Use C<< { max => 0 } >> to get all results.

B<References:> L<Listing category contents|https://github.com/MediaWiki-Bot/MediaWiki-Bot/wiki/Listing-category-contents>,
L<API:Categorymembers|https://www.mediawiki.org/wiki/API:Categorymembers>

=cut

sub get_pages_in_category {
    my $self     = shift;
    my $category = shift;
    my $options  = shift;

    if ($category =~ m/:/) {    # It might have a namespace name
        my ($cat) = split(/:/, $category, 2);
        if ($cat ne 'Category') {    # 'Category' is a canonical name for ns14
            my $ns_data     = $self->_get_ns_data();
            my $cat_ns_name = $ns_data->{+NS_CATEGORY};
            if ($cat ne $cat_ns_name) {
                $category = "$cat_ns_name:$category";
            }
        }
    }
    else {                                             # Definitely no namespace name, since there's no colon
        $category = "Category:$category";
    }
    warn "Category to fetch is [[$category]]" if $self->{debug} > 1;

    my $hash = {
        action  => 'query',
        list    => 'categorymembers',
        cmtitle => $category,
        cmlimit => 'max',
    };
    $options->{max} = 1 unless defined($options->{max});
    delete($options->{max}) if $options->{max} == 0;

    my $res = $self->{api}->list($hash, $options);
    return RET_TRUE if not ref $res; # Not a hashref when using callback
    return $self->_handle_api_error() unless $res;

    return map { $_->{title} } @$res;
}

=head2 get_all_pages_in_category

    my @pages = $bot->get_all_pages_in_category($category, $options_hashref);

Returns an array containing the names of B<all> pages in the specified category
(include the Category: prefix), including sub-categories. The $options_hashref
is described fully in L</"Options hashref">.

B<References:> L<Listing category contents|https://github.com/MediaWiki-Bot/MediaWiki-Bot/wiki/Listing-category-contents>,
L<API:Categorymembers|https://www.mediawiki.org/wiki/API:Categorymembers>

=cut

{    # Instead of using the state pragma, use a bare block
    my %data;

    sub get_all_pages_in_category {
        my $self          = shift;
        my $base_category = shift;
        my $options       = shift;
        $options->{max} = 0 unless defined($options->{max});

        my @first = $self->get_pages_in_category($base_category, $options);
        %data = () unless $_[0];    # This is a special flag for internal use.
                                    # It marks a call to this method as being
                                    # internal. Since %data is a fake state variable,
                                    # it needs to be cleared for every *external*
                                    # call, but not cleared when the call is recursive.

        my $ns_data     = $self->_get_ns_data();
        my $cat_ns_name = $ns_data->{+NS_CATEGORY};

        foreach my $page (@first) {
            if ($page =~ m/^$cat_ns_name:/) {
                if (!exists($data{$page})) {
                    $data{$page} = '';
                    my @pages = $self->get_all_pages_in_category($page, $options, 1);
                    foreach (@pages) {
                        $data{$_} = '';
                    }
                }
                else {
                    $data{$page} = '';
                }
            }
            else {
                $data{$page} = '';
            }
        }
        return keys %data;
    }
}    # This ends the bare block around get_all_pages_in_category()

=head2 get_all_categories

Returns an array containing the names of all categories.

    my @categories = $bot->get_all_categories();
    print "The categories are:\n@categories\n";

Use C<< { max => 0 } >> to get all results. The default number
of categories returned is 10, the maximum allowed is 500.

B<References:> L<API:Allcategories|https://www.mediawiki.org/wiki/API:Allcategories>

=cut

sub get_all_categories {
    my $self     = shift;
    my $options  = shift;

    my $query = {
        action => 'query',
        list => 'allcategories',
    };

    if ( defined $options && $options->{'max'} == '0' ) {
        $query->{'aclimit'} = 'max';
    }

    my $res = $self->{api}->api($query);
    return $self->_handle_api_error() unless $res;

    return map { $_->{'*'} } @{ $res->{'query'}->{'allcategories'} };
}

=head2 linksearch

Runs a linksearch on the specified $link and returns an array containing
anonymous hashes with keys 'url' for the outbound URL, and 'title' for the page
the link is on.

Additional parameters are:

=over 4

=item *

A namespace number to search (pass an arrayref to search in multiple namespaces).

=item *

You can search by $protocol (http is default).

=item *

$options_hashref is fully documented in L</"Options hashref">:

Set I<max> in $options to get more than one query's worth of results:

    my $options = { max => 10, }; # I only want some results
    my @links = $bot->linksearch("slashdot.org", 1, undef, $options);
    foreach my $hash (@links) {
        my $url = $hash->{'url'};
        my $page = $hash->{'title'};
        print "$page: $url\n";
    }

Set I<hook> to a subroutine reference to use a callback hook for incremental
processing:

    my $options = { hook => \&mysub, }; # I want to do incremental processing
    $bot->linksearch("slashdot.org", 1, undef, $options);
    sub mysub {
        my ($res) = @_;
        foreach my $hashref (@$res) {
            my $url  = $hashref->{'url'};
            my $page = $hashref->{'title'};
            print "$page: $url\n";
        }
    }

=back

B<References:> L<Finding external links|https://github.com/MediaWiki-Bot/MediaWiki-Bot/wiki/Finding-external-links>,
L<API:Exturlusage|https://www.mediawiki.org/wiki/API:Exturlusage>

=cut

sub linksearch {
    my $self    = shift;
    my $link    = shift;
    my $ns      = shift;
    my $prot    = shift;
    my $options = shift;

    $ns = join('|', @$ns) if (ref $ns eq 'ARRAY');

    my $hash = {
        action      => 'query',
        list        => 'exturlusage',
        euprop      => 'url|title',
        euquery     => $link,
        eulimit     => 'max',
    };
    $hash->{eunamespace} = $ns if defined $ns;
    $hash->{euprotocol}  = $prot if $prot;
    $options->{max} = 1 unless $options->{max};

    my $res = $self->{api}->list($hash, $options);
    return $self->_handle_api_error() unless $res;
    return RET_TRUE if not ref $res; # When using a callback hook, this won't be a reference

    return map {{
        url   => $_->{url},
        title => $_->{title},
    }} @$res;

}

=head2 purge_page

Purges the server cache of the specified $page. Returns true on success; false
on failure. Pass an array reference to purge multiple pages.

If you really care, a true return value is the number of pages successfully
purged. You could check that it is the same as the number you wanted to
purge - maybe some pages don't exist, or you passed invalid titles, or you
aren't allowed to purge the cache:

    my @to_purge = ('Main Page', 'A', 'B', 'C', 'Very unlikely to exist');
    my $size = scalar @to_purge;

    print "all-at-once:\n";
    my $success = $bot->purge_page(\@to_purge);

    if ($success == $size) {
        print "@to_purge: OK ($success/$size)\n";
    }
    else {
        my $missed = @to_purge - $success;
        print "We couldn't purge $missed pages (list was: "
            . join(', ', @to_purge)
            . ")\n";
    }

    # OR
    print "\n\none-at-a-time:\n";
    foreach my $page (@to_purge) {
        my $ok = $bot->purge_page($page);
        print "$page: $ok\n";
    }

B<References:> L<Purging the server cache|https://github.com/MediaWiki-Bot/MediaWiki-Bot/wiki/Purging-the-server-cache>,
L<API:Purge|https://www.mediawiki.org/wiki/API:Purge>

=cut

sub purge_page {
    my $self = shift;
    my $page = shift;

    my $hash;
    if (ref $page eq 'ARRAY') {             # If it is an array reference...
        $hash = {
            action => 'purge',
            titles => join('|', @$page),    # dereference it and purge all those titles
        };
    }
    else {                                  # Just one page
        $hash = {
            action => 'purge',
            titles => $page,
        };
    }

    my $res = $self->{api}->api($hash);
    return $self->_handle_api_error() unless $res;
    my $success = 0;
    foreach my $hashref (@{ $res->{purge} }) {
        $success++ if exists $hashref->{purged};
    }
    return $success;
}

=head2 get_namespace_names

    my %namespace_names = $bot->get_namespace_names();

Returns a hash linking the namespace id, such as 1, to its named equivalent,
such as "Talk".

B<References:> L<API:Meta#siteinfo|https://www.mediawiki.org/wiki/API:Meta#siteinfo_.2F_si>

=cut

sub get_namespace_names {
    my $self = shift;
    my $res = $self->{api}->api({
            action => 'query',
            meta   => 'siteinfo',
            siprop => 'namespaces',
    });
    return $self->_handle_api_error() unless $res;
    return map { $_ => $res->{query}->{namespaces}->{$_}->{'*'} }
        keys %{ $res->{query}->{namespaces} };
}

=head2 image_usage

Gets a list of pages which include a certain $image. Include the C<File:>
namespace prefix to avoid incurring an extra round-trip (which will also emit
a deprecation warnings).

Additional parameters are:

=over 4

=item *

A namespace number to fetch results from (or an arrayref of multiple namespace
numbers)

=item *

One of all, redirect, or nonredirects.

=item *

$options is a hashref as described in the section for L</linksearch>.

=back

    my @pages = $bot->image_usage("File:Albert Einstein Head.jpg");

Or, make use of the L</"Options hashref"> to do incremental processing:

    $bot->image_usage("File:Albert Einstein Head.jpg",
        undef, undef,
        { hook=>\&mysub, max=>5 }
    );
    sub mysub {
        my $res = shift;
        foreach my $page (@$res) {
            my $title = $page->{'title'};
            print "$title\n";
        }
    }

B<References:> L<API:Imageusage|https://www.mediawiki.org/wiki/API:Imageusage>

=cut

sub image_usage {
    my $self    = shift;
    my $image   = shift;
    my $ns      = shift;
    my $filter  = shift;
    my $options = shift;

    if ($image !~ m/^File:|Image:/) {
        warnings::warnif('deprecated', q{Please include the canonical File: }
            . q{namespace in the image name. If you don't, MediaWiki::Bot might }
            . q{incur a network round-trip to get the localized namespace name});
        my $ns_data = $self->_get_ns_data();
        my $file_ns_name = $ns_data->{+NS_FILE};
        if ($image !~ m/^\Q$file_ns_name\E:/) {
            $image = "$file_ns_name:$image";
        }
    }

    $options->{max} = 1 unless defined($options->{max});
    delete($options->{max}) if $options->{max} == 0;

    $ns = join('|', @$ns) if (ref $ns eq 'ARRAY');

    my $hash = {
        action          => 'query',
        list            => 'imageusage',
        iutitle         => $image,
        iulimit         => 'max',
    };
    $hash->{iunamespace} = $ns if defined $ns;
    if (defined($filter) and $filter =~ m/(all|redirects|nonredirects)/) {
        $hash->{'iufilterredir'} = $1;
    }
    my $res = $self->{api}->list($hash, $options);
    return $self->_handle_api_error() unless $res;
    return RET_TRUE if not ref $res; # When using a callback hook, this won't be a reference

    return map { $_->{title} } @$res;
}

=head2 global_image_usage($image, $results, $filterlocal)

Returns an array of hashrefs of data about pages which use the given image.

    my @data = $bot->global_image_usage('File:Albert Einstein Head.jpg');

The keys in each hashref are title, url, and wiki. C<$results> is the maximum
number of results that will be returned (not the maximum number of requests that
will be sent, like C<max> in the L</"Options hashref">); the default is to
attempt to fetch 500 (set to 0 to get all results). C<$filterlocal> will filter
out local uses of the image.

B<References:> L<Extension:GlobalUsage#API|https://www.mediawiki.org/wiki/Extension:GlobalUsage#API>

=cut

sub global_image_usage {
    my $self    = shift;
    my $image   = shift;
    my $limit   = shift;
    my $filterlocal = shift;
    $limit = defined $limit ? $limit : 500;

    if ($image !~ m/^File:|Image:/) {
        my $ns_data = $self->_get_ns_data();
        my $image_ns_name = $ns_data->{+NS_FILE};
        if ($image !~ m/^\Q$image_ns_name\E:/) {
            $image = "$image_ns_name:$image";
        }
    }

    my @data;
    my $cont;
    while ($limit ? scalar @data < $limit : 1) {
        my $hash = {
            action          => 'query',
            prop            => 'globalusage',
            titles          => $image,
            # gufilterlocal   => $filterlocal,
            gulimit         => 'max',
        };
        $hash->{gufilterlocal} = $filterlocal if $filterlocal;
        $hash->{gucontinue}    = $cont if $cont;

        my $res = $self->{api}->api($hash);
        return $self->_handle_api_error() unless $res;

        $cont = $res->{'query-continue'}->{globalusage}->{gucontinue};
        warn "gucontinue: $cont\n" if $cont and $self->{debug} > 1;
        my $page_id = (keys %{ $res->{query}->{pages} })[0];
        my $results = $res->{query}->{pages}->{$page_id}->{globalusage};
        push @data, @$results;
        last unless $cont;
    }

    return @data > $limit
        ? @data[0 .. $limit-1]
        : @data;
}

=head2 links_to_image

A backward-compatible call to L</image_usage>. You can provide only the image
title.

B<This method is deprecated>, and will emit deprecation warnings.

=cut

sub links_to_image {
    warnings::warnif('deprecated', 'links_to_image is an alias of image_usage; '
        . 'please use the new name');
    my $self = shift;
    return $self->image_usage($_[0]);
}

=head2 is_blocked

    my $blocked = $bot->is_blocked('User:Mike.lifeguard');

Checks if a user is currently blocked.

B<References:> L<API:Blocks|https://www.mediawiki.org/wiki/API:Blocks>

=cut

sub is_blocked {
    my $self = shift;
    my $user = shift;

    # http://en.wikipedia.org/w/api.php?action=query&meta=blocks&bkusers=$user&bklimit=1&bkprop=id
    my $hash = {
        action  => 'query',
        list    => 'blocks',
        bkusers => $user,
        bklimit => 1,
        bkprop  => 'id',
    };
    my $res = $self->{api}->api($hash);
    return $self->_handle_api_error() unless $res;

    my $number = scalar @{ $res->{query}->{blocks} }; # The number of blocks returned
    if ($number == 1) {
        return RET_TRUE;
    }
    elsif ($number == 0) {
        return RET_FALSE;
    }
    else {
        confess "This query should return at most one result, but the API returned more than that.";
    }
}

=head2 test_blocked

Retained for backwards compatibility. Use L</is_blocked> for clarity.

B<This method is deprecated>, and will emit deprecation warnings.

=cut

sub test_blocked { # For backwards-compatibility
    warnings::warnif('deprecated', 'test_blocked is an alias of is_blocked; '
        . 'please use the new name. This alias might be removed in a future release');
    return (is_blocked(@_));
}

=head2 test_image_exists

Checks if an image exists at $page.

=over 4

=item *

C<FILE_NONEXISTENT> (0) means "Nothing there"

=item *

C<FILE_LOCAL> (1) means "Yes, an image exists locally"

=item *

C<FILE_SHARED> (2) means "Yes, an image exists on L<Commons|http://commons.wikimedia.org>"

=item *

C<FILE_PAGE_TEXT_ONLY> (3) means "No image exists, but there is text on the page"

=back

If you pass in an arrayref of images, you'll get out an arrayref of
results.

    use MediaWiki::Bot::Constants;
    my $exists = $bot->test_image_exists('File:Albert Einstein Head.jpg');
    if ($exists == FILE_NONEXISTENT) {
        print "Doesn't exist\n";
    }
    elsif ($exists == FILE_LOCAL) {
        print "Exists locally\n";
    }
    elsif ($exists == FILE_SHARED) {
        print "Exists on Commons\n";
    }
    elsif ($exists == FILE_PAGE_TEXT_ONLY) {
        print "Page exists, but no image\n";
    }

B<References:> L<API:Properties#imageinfo|https://www.mediawiki.org/wiki/API:Properties#imageinfo_.2F_ii>

=cut

sub test_image_exists {
    my $self  = shift;
    my $image = shift;

    my $multi;
    if (ref $image eq 'ARRAY') {
        $multi = $image; # so we know to return a hash/scalar & keep track of order
        $image = join('|', @$image);
    }

    my $res = $self->{api}->api({
        action  => 'query',
        titles  => $image,
        iilimit => 1,
        prop    => 'imageinfo'
    });
    return $self->_handle_api_error() unless $res;

    my @sorted_ids;
    if ($multi) {
        my %mapped;
        $mapped{ $res->{query}->{pages}->{$_}->{title} } = $_
            for (keys %{ $res->{query}->{pages} });
        foreach my $file ( @$multi ) {
            unshift @sorted_ids, $mapped{$file};
        }
    }
    else {
        push @sorted_ids, keys %{ $res->{query}->{pages} };
    }
    my @return;
    foreach my $id (@sorted_ids) {
        if ($res->{query}->{pages}->{$id}->{imagerepository} eq 'shared') {
            if ($multi) {
                unshift @return, FILE_SHARED;
            }
            else {
                return FILE_SHARED;
            }
        }
        elsif (exists($res->{query}->{pages}->{$id}->{missing})) {
            if ($multi) {
                unshift @return, FILE_NONEXISTENT;
            }
            else {
                return FILE_NONEXISTENT;
            }
        }
        elsif ($res->{query}->{pages}->{$id}->{imagerepository} eq '') {
            if ($multi) {
                unshift @return, FILE_PAGE_TEXT_ONLY;
            }
            else {
                return FILE_PAGE_TEXT_ONLY;
            }
        }
        elsif ($res->{query}->{pages}->{$id}->{imagerepository} eq 'local') {
            if ($multi) {
                unshift @return, FILE_LOCAL;
            }
            else {
                return FILE_LOCAL;
            }
        }
    }

    return \@return;
}

=head2 get_pages_in_namespace

    $bot->get_pages_in_namespace($namespace, $limit, $options_hashref);

Returns an array containing the names of all pages in the specified namespace.
The $namespace_id must be a number, not a namespace name.

Setting $page_limit is optional, and specifies how many items to retrieve at
once. Setting this to 'max' is recommended, and this is the default if omitted.
If $page_limit is over 500, it will be rounded up to the next multiple of 500.
If $page_limit is set higher than you are allowed to use, it will silently be
reduced. Consider setting key 'max' in the L</"Options hashref"> to
retrieve multiple sets of results:

    # Gotta get 'em all!
    my @pages = $bot->get_pages_in_namespace(6, 'max', { max => 0 });

B<References:> L<API:Allpages|https://www.mediawiki.org/wiki/API:Allpages>

=cut

sub get_pages_in_namespace {
    my $self      = shift;
    my $namespace = shift;
    my $limit     = shift || 'max';
    my $options   = shift;

    my $hash = {
        action      => 'query',
        list        => 'allpages',
        apnamespace => $namespace,
        aplimit     => $limit,
    };
    $options->{max} = 1 unless defined $options->{max};
    delete $options->{max} if exists $options->{max} and $options->{max} == 0;

    my $res = $self->{api}->list($hash, $options);
    return $self->_handle_api_error() unless $res;
    return RET_TRUE if not ref $res; # Not a ref when using callback
    return map { $_->{title} } @$res;
}

=head2 count_contributions

    my $count = $bot->count_contributions($user);

Uses the API to count $user's contributions.

B<References:> L<API:Users|https://www.mediawiki.org/wiki/API:Users>

=cut

sub count_contributions {
    my $self     = shift;
    my $username = shift;
    $username =~ s/User://i;    # Strip namespace

    my $res = $self->{api}->list({
            action  => 'query',
            list    => 'users',
            ususers => $username,
            usprop  => 'editcount'
        },
        { max => 1 });
    return $self->_handle_api_error() unless $res;
    return ${$res}[0]->{editcount};
}

=head2 timed_count_contributions

    ($timed_edits_count, $total_count) = $bot->timed_count_contributions($user, $days);

Uses the API to count $user's contributions in last number of $days and total number of user's contributions (if needed).

Example: If you want to get user contribs for last 30 and 365 days, and total number of edits you would write
something like this:

    my ($last30days, $total) = $bot->timed_count_contributions($user, 30);
    my $last365days = $bot->timed_count_contributions($user, 365);

You could get total number of edits also by separately calling count_contributions like this:

    my $total = $bot->count_contributions($user);

and use timed_count_contributions only in scalar context, but that would mean one more call to server (meaning more
server load) of which you are excused as timed_count_contributions returns array with two parameters.

B<References:> L<Extension:UserDailyContribs|https://www.mediawiki.org/wiki/Extension:UserDailyContribs>

=cut

sub timed_count_contributions {
    my $self     = shift;
    my $username = shift;
    my $days     = shift;
    $username =~ s/User://i;    # Strip namespace

    my $res = $self->{api}->api({
            action  => 'userdailycontribs',
            user    => $username,
            daysago => $days,
        },
        { max => 1 });
    return $self->_handle_api_error() unless $res;
    return ($res->{userdailycontribs}->{timeFrameEdits}, $res->{userdailycontribs}->{totalEdits});
}

=head2 last_active

    my $latest_timestamp = $bot->last_active($user);

Returns the last active time of $user in C<YYYY-MM-DDTHH:MM:SSZ>.

B<References:> L<API:Usercontribs|https://www.mediawiki.org/wiki/API:Usercontribs>

=cut

sub last_active {
    my $self     = shift;
    my $username = shift;
    my $res = $self->{api}->list({
            action  => 'query',
            list    => 'usercontribs',
            ucuser  => $username,
            uclimit => 1
        },
        { max => 1 });
    return $self->_handle_api_error() unless $res;
    return ${$res}[0]->{timestamp};
}

=head2 recent_edit_to_page

     my ($timestamp, $user) = $bot->recent_edit_to_page($title);

Returns timestamp and username for most recent (top) edit to $page.

B<References:> L<API:Properties#revisions|https://www.mediawiki.org/wiki/API:Properties#revisions_.2F_rv>

=cut

sub recent_edit_to_page {
    my $self = shift;
    my $page = shift;
    my $res  = $self->{api}->api({
            action  => 'query',
            prop    => 'revisions',
            titles  => $page,
            rvlimit => 1
        },
        { max => 1 });
    return $self->_handle_api_error() unless $res;
    my $data = ( %{ $res->{query}->{pages} } )[1];
    return ($data->{revisions}[0]->{timestamp},
        $data->{revisions}[0]->{user});
}

=head2 get_users

    my @recent_editors = $bot->get_users($title, $limit, $revid, $direction);

Gets the most recent editors to $page, up to $limit, starting from $revision
and going in $direction.

B<References:> L<API:Properties#revisions|https://www.mediawiki.org/wiki/API:Properties#revisions_.2F_rv>

=cut

sub get_users {
    my $self      = shift;
    my $pagename  = shift;
    my $limit     = shift || 'max';
    my $rvstartid = shift;
    my $direction = shift;

    if ($limit > 50) {
        $self->{errstr} = "Error requesting history for $pagename: Limit may not be set to values above 50";
        carp $self->{errstr};
        return;
    }
    my $hash = {
        action  => 'query',
        prop    => 'revisions',
        titles  => $pagename,
        rvprop  => 'ids|timestamp|user|comment',
        rvlimit => $limit,
    };
    $hash->{rvstartid} = $rvstartid if ($rvstartid);
    $hash->{rvdir}     = $direction if ($direction);

    my $res = $self->{api}->api($hash);
    return $self->_handle_api_error() unless $res;

    my ($id) = keys %{ $res->{query}->{pages} };
    return map { $_->{user} } @{$res->{query}->{pages}->{$id}->{revisions}};
}

=head2 was_blocked

    for ("Mike.lifeguard", "Jimbo Wales") {
        print "$_ was blocked\n" if $bot->was_blocked($_);
    }

Returns whether $user has ever been blocked.

B<References:> L<API:Logevents|https://www.mediawiki.org/wiki/API:Logevents>

=cut

sub was_blocked {
    my $self = shift;
    my $user = shift;
    $user =~ s/User://i;    # Strip User: prefix, if present

    # http://en.wikipedia.org/w/api.php?action=query&list=logevents&letype=block&letitle=User:127.0.0.1&lelimit=1&leprop=ids
    my $hash = {
        action  => 'query',
        list    => 'logevents',
        letype  => 'block',
        letitle => "User:$user",    # Ensure the User: prefix is there!
        lelimit => 1,
        leprop  => 'ids',
    };

    my $res = $self->{api}->api($hash);
    return $self->_handle_api_error() unless $res;

    my $number = scalar @{ $res->{query}->{logevents} };    # The number of blocks returned
    if ($number == 1) {
        return RET_TRUE;
    }
    elsif ($number == 0) {
        return RET_FALSE;
    }
    else {
        confess "This query should return at most one result, but the API returned more than that.";
    }
}

=head2 test_block_hist

Retained for backwards compatibility. Use L</was_blocked> for clarity.

B<This method is deprecated>, and will emit deprecation warnings.

=cut

sub test_block_hist { # Backwards compatibility
    warnings::warnif('deprecated', 'test_block_hist is an alias of was_blocked; '
        . 'please use the new method name. This alias might be removed in a future release');
    return (was_blocked(@_));
}

=head2 expandtemplates

    my $expanded = $bot->expandtemplates($title, $wikitext);

Expands templates on $page, using $text if provided, otherwise loading the page
text automatically.

B<References:> L<API:Parsing wikitext|https://www.mediawiki.org/wiki/API:Parsing_wikitext>

=cut

sub expandtemplates {
    my $self = shift;
    my $page = shift;
    my $text = shift;

    unless ($text) {
        croak q{You must provide a page title} unless $page;
        $text = $self->get_text($page);
    }

    my $hash = {
        action => 'expandtemplates',
        prop   => 'wikitext',
        ( $page ? (title  => $page) : ()),
        text   => $text,
    };
    my $res = $self->{api}->api($hash);
    return $self->_handle_api_error() unless $res;

    return exists $res->{expandtemplates}->{'*'}
        ? $res->{expandtemplates}->{'*'}
        : $res->{expandtemplates}->{wikitext};
}

=head2 get_allusers

    my @users = $bot->get_allusers($limit, $user_group, $options_hashref);

Returns an array of all users. Default $limit is 500. Optionally specify a
$group (like 'sysop') to list that group only. The last optional parameter
is an L</"Options hashref">.

B<References:> L<API:Allusers|https://www.mediawiki.org/wiki/API:Allusers>

=cut

sub get_allusers {
    my $self   = shift;
    my $limit  = shift || 'max';
    my $group  = shift;
    my $opts   = shift;

    my $hash = {
            action  => 'query',
            list    => 'allusers',
            aulimit => $limit,
    };
    $hash->{augroup} = $group if defined $group;
    $opts->{max} = 1 unless exists $opts->{max};
    delete $opts->{max} if exists $opts->{max} and $opts->{max} == 0;
    my $res = $self->{api}->list($hash, $opts);
    return $self->_handle_api_error() unless $res;
    return RET_TRUE if not ref $res; # Not a ref when using callback

    return map { $_->{name} } @$res;
}

=head2 db_to_domain

Converts a wiki/database name (enwiki) to the domain name (en.wikipedia.org).

    my @wikis = ("enwiki", "kowiki", "bat-smgwiki", "nonexistent");
    foreach my $wiki (@wikis) {
        my $domain = $bot->db_to_domain($wiki);
        next if !defined($domain);
        print "$wiki: $domain\n";
    }

You can pass an arrayref to do bulk lookup:

    my @wikis = ("enwiki", "kowiki", "bat-smgwiki", "nonexistent");
    my $domains = $bot->db_to_domain(\@wikis);
    foreach my $domain (@$domains) {
        next if !defined($domain);
        print "$domain\n";
    }

B<References:> L<Extension:SiteMatrix|https://www.mediawiki.org/wiki/Extension:SiteMatrix>

=cut

sub db_to_domain {
    my $self = shift;
    my $wiki = shift;

    if (!$self->{sitematrix}) {
        $self->_get_sitematrix();
    }

    if (ref $wiki eq 'ARRAY') {
        my @return;
        foreach my $w (@$wiki) {
            $wiki =~ s/_p$//;                               # Strip off a _p suffix, if present
            my $domain = $self->{sitematrix}->{$w} || undef;
            $domain =~ s/^https\:\/\/// if (defined $domain); # Strip off a https:// prefix, if present
            push(@return, $domain);
        }
        return \@return;
    }
    else {
        $wiki =~ s/_p$//;                                   # Strip off a _p suffix, if present
        my $domain = $self->{sitematrix}->{$wiki} || undef;
        $domain =~ s/^https\:\/\/// if (defined $domain);   # Strip off a https:// prefix, if present
        return $domain;
    }
}

=head2 domain_to_db

    my $db = $bot->domain_to_db($domain_name);

As you might expect, does the opposite of L</domain_to_db>: Converts a domain
name (meta.wikimedia.org) into a database/wiki name (metawiki).

B<References:> L<Extension:SiteMatrix|https://www.mediawiki.org/wiki/Extension:SiteMatrix>

=cut

sub domain_to_db {
    my $self = shift;
    my $wiki = shift;

    if (!$self->{sitematrix}) {
        $self->_get_sitematrix();
    }

    if (ref $wiki eq 'ARRAY') {
        my @return;
        foreach my $w (@$wiki) {
            $w = "https://".$w if ($w !~ /^https\:\//); # Prepend a https:// prefix, if not present
            my $db = $self->{sitematrix}->{$w} || undef;
            push(@return, $db);
        }
        return \@return;
    }
    else {
        $wiki = "https://".$wiki if ($wiki !~ /^https\:\//); # Prepend a https:// prefix, if not present
        my $db = $self->{sitematrix}->{$wiki} || undef;
        return $db;
    }
}

=head2 diff

This allows retrieval of a diff from the API. The return is a scalar containing
the I<HTML table> of the diff. Options are passed as a hashref with keys:

=over 4

=item *

I<title> is the title to use. Provide I<either> this or revid.

=item *

I<revid> is any revid to diff from. If you also specified title, only title will
be honoured.

=item *

I<oldid> is an identifier to diff to. This can be a revid, or the special values
'cur', 'prev' or 'next'

=back

B<References:> L<API:Properties#revisions|https://www.mediawiki.org/wiki/API:Properties#revisions_.2F_rv>

=cut

sub diff {
    my $self = shift;
    my $title;
    my $revid;
    my $oldid;

    if (ref $_[0] eq 'HASH') {
        $title = $_[0]->{title};
        $revid = $_[0]->{revid};
        $oldid = $_[0]->{oldid};
    }
    else {
        $title = shift;
        $revid = shift;
        $oldid = shift;
    }

    my $hash = {
        action   => 'query',
        prop     => 'revisions',
        rvdiffto => $oldid,
    };
    if ($title) {
        $hash->{titles}  = $title;
        $hash->{rvlimit} = 1;
    }
    elsif ($revid) {
        $hash->{'revids'} = $revid;
    }

    my $res = $self->{api}->api($hash);
    return $self->_handle_api_error() unless $res;
    my @revids = keys %{ $res->{query}->{pages} };
    my $diff   = $res->{query}->{pages}->{ $revids[0] }->{revisions}->[0]->{diff}->{'*'};

    return $diff;
}

=head2 prefixindex

This returns an array of hashrefs containing page titles that start with the
given $prefix. The hashref has keys 'title' and 'redirect' (present if the
page is a redirect, not present otherwise).

Additional parameters are:

=over 4

=item *

One of all, redirects, or nonredirects

=item *

A single namespace number (unlike linksearch etc, which can accept an arrayref
of numbers).

=item *

$options_hashref as described in L</"Options hashref">.

=back

    my @prefix_pages = $bot->prefixindex("User:Mike.lifeguard");
    # Or, the more efficient equivalent
    my @prefix_pages = $bot->prefixindex("Mike.lifeguard", 2);
    foreach my $hashref (@pages) {
        my $title = $hashref->{'title'};
        if $hashref->{'redirect'} {
            print "$title is a redirect\n";
        }
        else {
            print "$title\n is not a redirect\n";
        }
    }

B<References:> L<API:Allpages|https://www.mediawiki.org/wiki/API:Allpages>

=cut

sub prefixindex {
    my $self    = shift;
    my $prefix  = shift;
    my $ns      = shift;
    my $filter  = shift;
    my $options = shift;

    if (defined($filter) and $filter =~ m/(all|redirects|nonredirects)/) {    # Verify
        $filter = $1;
    }

    if (!defined $ns && $prefix =~ m/:/) {
        print STDERR "Converted '$prefix' to..." if $self->{debug} > 1;
        my ($name) = split(/:/, $prefix, 2);
        my $ns_data = $self->_get_ns_data();
        $ns = $ns_data->{$name};
        $prefix =~ s/^$name://;
        warn "'$prefix' with a namespace filter $ns" if $self->{debug} > 1;
    }

    my $hash = {
        action   => 'query',
        list     => 'allpages',
        apprefix => $prefix,
        aplimit  => 'max',
    };
    $hash->{apnamespace}   = $ns     if defined $ns;
    $hash->{apfilterredir} = $filter if $filter;
    $options->{max} = 1 unless $options->{max};

    my $res = $self->{api}->list($hash, $options);

    return $self->_handle_api_error() unless $res;
    return RET_TRUE if not ref $res; # Not a ref when using callback hook

    return map {
        { title => $_->{title}, redirect => defined $_->{redirect} }
    } @$res;
}

=head2 search

This is a simple search for your $search_term in page text. It returns an array
of page titles matching.

Additional optional parameters are:

=over 4

=item *

A namespace number to search in, or an arrayref of numbers (default is the
main namespace)

=item *

$options_hashref is a hashref as described in L</"Options hashref">:

=back

    my @pages = $bot->search("Mike.lifeguard", 2);
    print "@pages\n";

Or, use a callback for incremental processing:

    my @pages = $bot->search("Mike.lifeguard", 2, { hook => \&mysub });
    sub mysub {
        my ($res) = @_;
        foreach my $hashref (@$res) {
            my $page = $hashref->{'title'};
            print "$page\n";
        }
    }

B<References:> L<API:Search|https://www.mediawiki.org/wiki/API:Search>

=cut

sub search {
    my $self    = shift;
    my $term    = shift;
    my $ns      = shift || 0;
    my $options = shift;

    if (ref $ns eq 'ARRAY') {    # Accept a hashref
        $ns = join('|', @$ns);
    }

    my $hash = {
        action   => 'query',
        list     => 'search',
        srnamespace => $ns,
        srsearch => $term,
        srwhat   => 'text',
        srlimit  => 'max',

        #srinfo      => 'totalhits',
        srprop      => 'size',
        srredirects => 0,
    };
    $options->{max} = 1 unless $options->{max};

    my $res = $self->{api}->list($hash, $options);
    return $self->_handle_api_error() unless $res;
    return RET_TRUE if not ref $res; # Not a ref when used with callback

    return map { $_->{title} } @$res;
}

=head2 get_log

This fetches log entries, and returns results as an array of hashes. The first
parameter is a hashref with keys:

=over 4

=item *

I<type> is the log type (block, delete...)

=item *

I<user> is the user who I<performed> the action. Do not include the User: prefix

=item *

I<target> is the target of the action. Where an action was performed to a page,
it is the page title. Where an action was performed to a user, it is
User:$username.

=back

The second is the familiar L</"Options hashref">.

    my $log = $bot->get_log({
            type => 'block',
            user => 'User:Mike.lifeguard',
        });
    foreach my $entry (@$log) {
        my $user = $entry->{'title'};
        print "$user\n";
    }

    $bot->get_log({
            type => 'block',
            user => 'User:Mike.lifeguard',
        },
        { hook => \&mysub, max => 10 }
    );
    sub mysub {
        my ($res) = @_;
        foreach my $hashref (@$res) {
            my $title = $hashref->{'title'};
            print "$title\n";
        }
    }

B<References:> L<API:Logevents|https://www.mediawiki.org/wiki/API:Logevents>

=cut

sub get_log {
    my $self    = shift;
    my $data    = shift;
    my $options = shift;

    my $log_type = $data->{type};
    my $user     = $data->{user};
    my $target   = $data->{target};

    if ($user) {
        my $ns_data      = $self->_get_ns_data();
        my $user_ns_name = $ns_data->{+NS_USER};
        $user =~ s/^$user_ns_name://;
    }

    my $hash = {
        action  => 'query',
        list    => 'logevents',
        lelimit => 'max',
    };
    $hash->{letype}  = $log_type if $log_type;
    $hash->{leuser}  = $user     if $user;
    $hash->{letitle} = $target   if $target;
    $options->{max} = 1 unless $options->{max};

    my $res = $self->{api}->list($hash, $options);
    return $self->_handle_api_error() unless $res;
    return RET_TRUE if not ref $res; # Not a ref when using callback

    return $res;
}

=head2 is_g_blocked

    my $is_globally_blocked = $bot->is_g_blocked('127.0.0.1');

Returns what IP/range block I<currently in place> affects the IP/range. The
return is a scalar of an IP/range if found (evaluates to true in boolean
context); undef otherwise (evaluates false in boolean context). Pass in a
single IP or CIDR range.

B<References:> L<Extension:GlobalBlocking|https://www.mediawiki.org/wiki/Extension:GlobalBlocking/API>

=cut

sub is_g_blocked {
    my $self = shift;
    my $ip   = shift;

    # http://en.wikipedia.org/w/api.php?action=query&list=globalblocks&bglimit=1&bgprop=address&bgip=127.0.0.1
    my $res = $self->{api}->api({
            action  => 'query',
            list    => 'globalblocks',
            bglimit => 1,
            bgprop  => 'address',
            # So handy! It searches for blocks affecting this IP or IP range,
            # including rangeblocks! Can't get that from UI.
            bgip    => $ip,
    });
    return $self->_handle_api_error() unless $res;
    return RET_FALSE unless ($res->{query}->{globalblocks}->[0]);

    return $res->{query}->{globalblocks}->[0]->{address};
}

=head2 was_g_blocked

    print "127.0.0.1 was globally blocked\n" if $bot->was_g_blocked('127.0.0.1');

Returns whether an IP/range was ever globally blocked. You should probably
call this method only when your bot is operating on Meta - this method will
warn if not.

B<References:> L<API:Logevents|https://www.mediawiki.org/wiki/API:Logevents>

=cut

sub was_g_blocked {
    my $self = shift;
    my $ip   = shift;
    $ip =~ s/User://i; # Strip User: prefix, if present

    # This query should always go to Meta
    unless ( $self->{host} eq 'meta.wikimedia.org' ) {
        carp "GlobalBlocking queries should probably be sent to Meta; it doesn't look like you're doing so" if $self->{debug};
    }

    # http://meta.wikimedia.org/w/api.php?action=query&list=logevents&letype=gblblock&letitle=User:127.0.0.1&lelimit=1&leprop=ids
    my $res = $self->{api}->api({
        action  => 'query',
        list    => 'logevents',
        letype  => 'gblblock',
        letitle => "User:$ip",    # Ensure the User: prefix is there!
        lelimit => 1,
        leprop  => 'ids',
    });

    return $self->_handle_api_error() unless $res;
    my $number = scalar @{ $res->{query}->{logevents} };    # The number of blocks returned

    if ($number == 1) {
        return RET_TRUE;
    }
    elsif ($number == 0) {
        return RET_FALSE;
    }
    else {
        confess "This query should return at most one result, but the API gave more than that.";
    }
}

=head2 was_locked

    my $was_locked = $bot->was_locked('Mike.lifeguard');

Returns whether a user was ever locked. You should probably call this method
only when your bot is operating on Meta - this method will warn if not.

B<References:> L<API:Logevents|https://www.mediawiki.org/wiki/API:Logevents>

=cut

sub was_locked {
    my $self = shift;
    my $user = shift;

    # This query should always go to Meta
    unless (
        $self->{api}->{config}->{api_url} =~ m,
            \Qhttp://meta.wikimedia.org/w/api.php\E
                |
            \Qhttps://secure.wikimedia.org/wikipedia/meta/w/api.php\E
        ,x    # /x flag is pretty awesome :)
        )
    {
        carp "CentralAuth queries should probably be sent to Meta; it doesn't look like you're doing so" if $self->{debug};
    }

    $user =~ s/^User://i;
    $user =~ s/\@global$//i;
    my $res = $self->{api}->api({
            action  => 'query',
            list    => 'logevents',
            letype  => 'globalauth',
            letitle => "User:$user\@global",
            lelimit => 1,
            leprop  => 'ids',
    });
    return $self->_handle_api_error() unless $res;
    my $number = scalar @{ $res->{query}->{logevents} };
    if ($number == 1) {
        return RET_TRUE;
    }
    elsif ($number == 0) {
        return RET_FALSE;
    }
    else {
        confess "This query should return at most one result, but the API returned more than that.";
    }
}

=head2 get_protection

Returns data on page protection as a array of up to two hashrefs. Each hashref
has a type, level, and expiry. Levels are 'sysop' and 'autoconfirmed'; types are
'move' and 'edit'; expiry is a timestamp. Additionally, the key 'cascade' will
exist if cascading protection is used.

    my $page = 'Main Page';
    $bot->edit({
        page    => $page,
        text    => rand(),
        summary => 'test',
    }) unless $bot->get_protection($page);

You can also pass an arrayref of page titles to do bulk queries:

    my @pages = ('Main Page', 'User:Mike.lifeguard', 'Project:Sandbox');
    my $answer = $bot->get_protection(\@pages);
    foreach my $title (keys %$answer) {
        my $protected = $answer->{$title};
        print "$title is protected\n" if $protected;
        print "$title is unprotected\n" unless $protected;
    }

B<References:> L<API:Properties#info|https://www.mediawiki.org/wiki/API:Properties#info_.2F_in>

=cut

sub get_protection {
    my $self = shift;
    my $page = shift;
    if (ref $page eq 'ARRAY') {
        $page = join('|', @$page);
    }

    my $hash = {
        action => 'query',
        titles => $page,
        prop   => 'info',
        inprop => 'protection',
    };
    my $res = $self->{api}->api($hash);
    return $self->_handle_api_error() unless $res;

    my $data = $res->{query}->{pages};

    my $out_data;
    foreach my $item (keys %$data) {
        my $title      = $data->{$item}->{title};
        my $protection = $data->{$item}->{protection};
        if (@$protection == 0) {
            $protection = undef;
        }
        $out_data->{$title} = $protection;
    }

    if (scalar keys %$out_data == 1) {
        return $out_data->{$page};
    }
    else {
        return $out_data;
    }
}

=head2 is_protected

This is a synonym for L</get_protection>, which should be used in preference.

B<This method is deprecated>, and will emit deprecation warnings.

=cut

sub is_protected {
    warnings::warnif('deprecated', 'is_protected is deprecated, and might be '
        . 'removed in a future release; please use get_protection instead');
    my $self = shift;
    return $self->get_protection(@_);
}

=head2 patrol

    $bot->patrol($rcid);

Marks a page or revision identified by the $rcid as patrolled. To mark several
RCIDs as patrolled, you may pass an arrayref of them. Returns false and sets
C<< $bot->{error} >> if the account cannot patrol.

B<References:> L<API:Patrol|https://www.mediawiki.org/wiki/API:Patrol>

=cut

sub patrol {
    my $self = shift;
    my $rcid = shift;

    if (ref $rcid eq 'ARRAY') {
        my @return;
        foreach my $id (@$rcid) {
            my $res = $self->patrol($id);
            push(@return, $res);
        }
        return @return;
    }
    else {
        my ($token) = $self->_get_edittoken('patrol');
        my $res = $self->{api}->api({
            action  => 'patrol',
            rcid    => $rcid,
            token   => $token,
        });
        return $self->_handle_api_error()
            if !$res
            or $self->{error}->{details} && $self->{error}->{details} =~ m/^(?:permissiondenied|badtoken)/;

        return $res;
    }
}

=head2 email

    $bot->email($user, $subject, $body);

This allows you to send emails through the wiki. All 3 of $user (without the
User: prefix), $subject and $body are required. If $user is an arrayref, this
will send the same email (subject and body) to all users.

B<References:> L<API:Email|https://www.mediawiki.org/wiki/API:Email>

=cut

sub email {
    my $self    = shift;
    my $user    = shift;
    my $subject = shift;
    my $body    = shift;

    if (ref $user eq 'ARRAY') {
        my @return;
        foreach my $target (@$user) {
            my $res = $self->email($target, $subject, $body);
            push(@return, $res);
        }
        return @return;
    }

    $user =~ s/^User://;
    if ($user =~ m/:/) {
        my $user_ns_name = $self->_get_ns_data()->{+NS_USER};
        $user =~ s/^$user_ns_name://;
    }

    my ($token) = $self->_get_edittoken;
    my $res = $self->{api}->api({
        action  => 'emailuser',
        target  => $user,
        subject => $subject,
        text    => $body,
        token   => $token,
    });
    return $self->_handle_api_error() unless $res;
    return $res;
}

=head2 top_edits

Returns an array of the page titles where the $user is the latest editor. The
second parameter is the familiar L<$options_hashref|/linksearch>.

    my @pages = $bot->top_edits("Mike.lifeguard", {max => 5});
    foreach my $page (@pages) {
        $bot->rollback($page, "Mike.lifeguard");
    }

Note that accessing the data with a callback happens B<before> filtering
the top edits is done. For that reason, you should use L</contributions>
if you need to use a callback. If you use a callback with top_edits(),
you B<will not> necessarily get top edits returned. It is only safe to use a
callback if you I<check> that it is a top edit:

    $bot->top_edits("Mike.lifeguard", { hook => \&rv });
    sub rv {
        my $data = shift;
        foreach my $page (@$data) {
            if (exists($page->{'top'})) {
                $bot->rollback($page->{'title'}, "Mike.lifeguard");
            }
        }
    }

B<References:> L<API:Usercontribs|https://www.mediawiki.org/wiki/API:Usercontribs>

=cut

sub top_edits {
    my $self    = shift;
    my $user    = shift;
    my $options = shift;

    $user =~ s/^User://;

    $options->{max} = 1 unless defined($options->{max});
    delete($options->{max}) if $options->{max} == 0;

    my $res = $self->{'api'}->list({
        action  => 'query',
        list    => 'usercontribs',
        ucuser  => $user,
        ucprop  => 'title|flags',
        uclimit => 'max',
    }, $options);
    return $self->_handle_api_error() unless $res;
    return RET_TRUE if not ref $res; # Not a ref when using callback

    return
        map { $_->{title} }
        grep { exists $_->{top} }
        @$res;
}

=head2 contributions

    my @contribs = $bot->contributions($user, $namespace, $options, $from, $to);

Returns an array of hashrefs of data for the user's contributions. $namespace
can be an arrayref of namespace numbers. $options can be specified as in
L</linksearch>.
$from and $to are optional timestamps. ISO 8601 date and time is recommended:
2001-01-15T14:56:00Z, see L<https://www.mediawiki.org/wiki/Timestamp> for all
possible formats.
Note that $from (=ucend) has to be before $to (=ucstart), unlike direct API access.

Specify an arrayref of users to get results for multiple users.

B<References:> L<API:Usercontribs|https://www.mediawiki.org/wiki/API:Usercontribs>

=cut

sub contributions {
    my $self = shift;
    my $user = shift;
    my $ns   = shift;
    my $opts = shift;
    my $from = shift; # ucend
    my $to   = shift; # ucstart

    if (ref $user eq 'ARRAY') {
        $user = join '|', map { my $u = $_; $u =~ s{^User:}{}; $u } @$user;
    }
    else {
        $user =~ s{^User:}{};
    }
    $ns = join '|', @$ns
        if ref $ns eq 'ARRAY';

    $opts->{max} = 1 unless defined($opts->{max});
    delete($opts->{max}) if $opts->{max} == 0;

    my $query = {
        action      => 'query',
        list        => 'usercontribs',
        ucuser      => $user,
        ( defined $ns ? (ucnamespace => $ns) : ()),
        ucprop      => 'ids|title|timestamp|comment|flags',
        uclimit     => 'max',
    };
    $query->{'ucstart'} = $to if defined $to;
    $query->{'ucend'} = $from if defined $from;
    my $res = $self->{api}->list($query, $opts);
    return $self->_handle_api_error() unless $res->[0];
    return RET_TRUE if not ref $res; # Not a ref when using callback

    return @$res;
}

=head2 upload

    $bot->upload({ data => $file_contents, summary => 'uploading file' });
    $bot->upload({ file => $file_name,     title   => 'Target filename.png' });

Upload a file to the wiki. Specify the file by either giving the filename, which
will be read in, or by giving the data directly.

B<References:> L<API:Upload|https://www.mediawiki.org/wiki/API:Upload>

=cut

sub upload {
    my $self = shift;
    my $args = shift;

    my $data = delete $args->{data};
    if (!defined $data and defined $args->{file}) {
            $data = do { local $/; open my $in, '<:raw', $args->{file} or die $!; <$in> };
    }
    unless (defined $data) {
        $self->{error}->{code} = ERR_PARAMS;
        $self->{error}->{details} = q{You must provide either file contents or a filename.};
        return undef;
    }
    unless (defined $args->{file} or defined $args->{title}) {
        $self->{error}->{code} = ERR_PARAMS;
        $self->{error}->{details} = q{You must specify a title to upload to.};
        return undef;
    }

    my $filename = $args->{title} || do { require File::Basename; File::Basename::basename($args->{file}) };
    my $success = $self->{api}->edit({
        action   => 'upload',
        filename => $filename,
        comment  => $args->{summary},
        file     => [ undef, $filename, Content => $data ],
    }) || return $self->_handle_api_error();
    return $success;
}

=head2 upload_from_url

Upload file directly from URL to the wiki. Specify URL, the new filename
and summary. Summary and new filename are optional.

    $bot->upload_from_url({
        url => 'http://some.domain.ext/pic.png',
        title => 'Target_filename.png',
        summary => 'uploading new pic',
    });

If on your target wiki is enabled uploading from URL, meaning C<$wgAllowCopyUploads>
is set to true in LocalSettings.php and you have appropriate user rights, you
can use this function to upload files to your wiki directly from remote server.

B<References:> L<API:Upload#Uploading_from_URL|https://www.mediawiki.org/wiki/API:Upload#Uploading_from_URL>

=cut

sub upload_from_url {
    my $self = shift;
    my $args = shift;

    my $url  = delete $args->{url};
    unless (defined $url) {
        $self->{error}->{code} = ERR_PARAMS;
        $self->{error}->{details} = q{You must provide URL of file to upload.};
        return undef;
    }

    my $filename = $args->{title} || do {
        require File::Basename;
        File::Basename::basename($url)
    };
    my $success = $self->{api}->edit({
        action   => 'upload',
        filename => $filename,
        comment  => $args->{summary},
        url      => $url,
        ignorewarnings => 1,
    }) || return $self->_handle_api_error();
    return $success;
}

=head2 usergroups

Returns a list of the usergroups a user is in:

    my @usergroups = $bot->usergroups('Mike.lifeguard');

B<References:> L<API:Users|https://www.mediawiki.org/wiki/API:Users>

=cut

sub usergroups {
    my $self = shift;
    my $user = shift;

    $user =~ s/^User://;

    my $res = $self->{api}->api({
        action  => 'query',
        list    => 'users',
        ususers => $user,
        usprop  => 'groups',
        ustoken => 'userrights',
    });
    return $self->_handle_api_error() unless $res;

    foreach my $res_user (@{ $res->{query}->{users} }) {
        next unless $res_user->{name} eq $user;

        # Cache the userrights token on the assumption that we'll use it shortly to change the rights
        $self->{userrightscache} = {
            user    => $user,
            token   => $res_user->{userrightstoken},
            groups  => $res_user->{groups},
        };

        return @{ $res_user->{groups} }; # SUCCESS
    }

    return $self->_handle_api_error({ code => ERR_API, details => qq{Results for $user weren't returned by the API} });
}

=head2 get_mw_version

Returns a hash ref with the MediaWiki version. The hash ref contains the keys
I<major>, I<minor>, I<patch>, and I<string>.
Returns undef on errors.

    my $mw_version = $bot->get_mw_version;

    # get version as string
    my $mw_ver_as_string = $mw_version->{'major'} . '.' . $mw_version->{'minor'};
    if(defined $mw_version->{'patch'}){
        $mw_ver_as_string .= '.' . $mw_version->{'patch'};
    }

    # or simply
    my $mw_ver_as_string = $mw_version->{'string'};

B<References:> L<API:Siteinfo|https://www.mediawiki.org/wiki/API:Siteinfo>

=cut

sub get_mw_version {
    my $self = shift;
    my $hash = {
        'action' => 'query',
        'meta'   => 'siteinfo',
        'siprop' => 'general',
    };
    my $res = $self->{api}->api($hash);
    return $self->_handle_api_error() unless $res;
    my $version = $res->{'query'}{'general'}{'generator'};
    if(defined $version && $version =~ /^MediaWiki (([0-9]+)\.([0-9]+)(?:\.([0-9]+))?+)/){
        $self->{'mw_version'} = {
            major => $2,
            minor => $3,
            patch => $4,
            string => $1,
        };
    }else{
        warn "could not fetch MediaWiki version.\n" if $self->{debug} > 1;
        return;
    }
    return {%{$self->{'mw_version'}}}; # don't return ref to member
}


################
# Internal use #
################

sub _get_edittoken { # Actually returns ($token, $base_timestamp, $start_timestamp)
    my $self = shift;
    my $page = shift || 'Main Page';
    my $type = shift || 'csrf';

    my $res = $self->{api}->api({
        action  => 'query',
        meta => 'siteinfo|tokens',
        titles  => $page,
        prop    => 'revisions',
        rvprop  => 'timestamp',
        type => $type,
    }) or return $self->_handle_api_error();

    my $data            = ( %{ $res->{query}->{pages} })[1];
    my $base_timestamp  = $data->{revisions}[0]->{timestamp};
    my $start_timestamp = $res->{query}->{general}->{time};
    my $token           = $res->{query}->{tokens}->{"${type}token"};

    return ($token, $base_timestamp, $start_timestamp);
}

sub _handle_api_error {
    my $self  = shift;
    my $error = shift;

    $self->{error} = {};

    carp 'Error code '
        . $self->{api}->{error}->{code}
        . ': '
        . $self->{api}->{error}->{details} if $self->{debug};
    $self->{error} =
        (defined $error and ref $error eq 'HASH' and exists $error->{code} and exists $error->{details})
        ? $error
        : $self->{api}->{error};

    return undef;
}

sub _is_loggedin {
    my $self = shift;

    my $is    = $self->_whoami() || return $self->_handle_api_error();
    my $ought = $self->{username};
    warn "Testing if logged in: we are $is, and we should be $ought" if $self->{debug} > 1;
    return ($is eq $ought);
}

sub _whoami {
    my $self = shift;

    my $res = $self->{api}->api({
        action => 'query',
        meta   => 'userinfo',
    }) or return $self->_handle_api_error();

    return $res->{query}->{userinfo}->{name};
}

sub _do_autoconfig {
    my $self = shift;

    # http://en.wikipedia.org/w/api.php?action=query&meta=userinfo&uiprop=rights|groups
    my $hash = {
        action => 'query',
        meta   => 'userinfo',
        uiprop => 'rights|groups',
    };
    my $res = $self->{api}->api($hash);
    return $self->_handle_api_error() unless  $res;
    return $self->_handle_api_error() unless  $res->{query};
    return $self->_handle_api_error() unless  $res->{query}->{userinfo};
    return $self->_handle_api_error() unless  $res->{query}->{userinfo}->{name};

    my $is    = $res->{query}->{userinfo}->{name};
    my $ought = $self->{username};

    # Should we try to recover by logging in again? croak?
    carp "We're logged in as $is but we should be logged in as $ought" if ($is ne $ought);

    my @rights            = @{ $res->{query}->{userinfo}->{rights} || [] };
    my $has_bot           = 0;
    my $default_assert    = 'user'; # At a *minimum*, the bot should be logged in.
    foreach my $right (@rights) {
        if ($right eq 'bot') {
            $has_bot        = 1;
            $default_assert = 'bot';
        }
    }

    my @groups = @{ $res->{query}->{userinfo}->{groups} || [] }; # there may be no groups
    my $is_sysop = 0;
    foreach my $group (@groups) {
        if ($group eq 'sysop') {
            $is_sysop = 1;
        }
    }

    unless ($has_bot && !$is_sysop) {
        warn "$is doesn't have a bot flag; edits will be visible in RecentChanges" if $self->{debug} > 1;
    }
    $self->{assert} = $default_assert unless $self->{assert};

    return RET_TRUE;
}

sub _get_sitematrix {
    my $self = shift;

    my $res = $self->{api}->api({ action => 'sitematrix' });
    return $self->_handle_api_error() unless $res;
    my %sitematrix = %{ $res->{sitematrix} };

    # This hash is a monstrosity (see http://sprunge.us/dfBD?pl), and needs
    # lots of post-processing to have a sane data structure :\
    my %by_db;
    SECTION: foreach my $hashref (%sitematrix) {
        if (ref $hashref ne 'HASH') {    # Yes, there are non-hashrefs in here, wtf?!
            if ($hashref eq 'specials') {
                SPECIAL: foreach my $special (@{ $sitematrix{specials} }) {
                    next SPECIAL
                        if (exists($special->{private})
                        or exists($special->{fishbowl}));

                    my $db     = $special->{code};
                    my $domain = $special->{url};
                    $domain =~ s,^http://,,;

                    $by_db{$db}     = $domain;
                }
            }
            next SECTION;
        }

        my $lang = $hashref->{code};

        WIKI: foreach my $wiki_ref ($hashref->{site}) {
            WIKI2: foreach my $wiki_ref2 (@$wiki_ref) {
                my $family = $wiki_ref2->{code};
                my $domain = $wiki_ref2->{url};
                $domain =~ s,^http://,,;

                my $db = $lang . $family;    # Is simple concatenation /always/ correct?

                $by_db{$db}     = $domain;
            }
        }
    }

    # Now filter out closed wikis
    my $response = $self->{api}->{ua}->get('http://noc.wikimedia.org/conf/closed.dblist');
    if ($response->is_success()) {
        my @closed_list = split(/\n/, $response->decoded_content);
        CLOSED: foreach my $closed (@closed_list) {
            delete($by_db{$closed});
        }
    }

    # Now merge in the reverse, so you can look up by domain as well as db
    my %by_domain;
    while (my ($key, $value) = each %by_db) {
        $by_domain{$value} = $key;
    }
    %by_db = (%by_db, %by_domain);

    # This could be saved to disk with Storable. Next time you call this
    # method, if mtime is less than, say, 14d, you could load it from
    # disk instead of over network.
    $self->{sitematrix} = \%by_db;

    return $self->{sitematrix};
}

sub _get_ns_data {
    my $self = shift;

    # If we have it already, return the cached data
    return $self->{ns_data} if exists $self->{ns_data};

    # If we haven't returned by now, we have to ask the API
    my %ns_data = $self->get_namespace_names();
    my %reverse = reverse %ns_data;
    %ns_data = (%ns_data, %reverse);
    $self->{ns_data} = \%ns_data;    # Save for later use

    return $self->{ns_data};
}

sub _get_ns_alias_data {
    my $self = shift;

    return $self->{ns_alias_data} if exists $self->{ns_alias_data};

    my $ns_res = $self->{api}->api({
        action  => 'query',
        meta    => 'siteinfo',
        siprop  => 'namespacealiases|namespaces',
    });

    my %ns_alias_data =
        map {   # Map namespace alias names like "WP" to the canonical namespace name
                # from the "namespaces" part of the response
            $_->{ns_alias} => $ns_res->{query}->{namespaces}->{ $_->{ns_number} }->{canonical}
        }
        map {   # Map namespace alias names (from the "namespacealiases" part of the response)
                # like "WP" to the namespace number (usd to look up canonical data in the
                # "namespaces" part of the response)
            { ns_alias => $_->{'*'}, ns_number => $_->{id} }
        } @{ $ns_res->{query}->{namespacealiases} };

    $self->{ns_alias_data} = \%ns_alias_data;
    return $self->{ns_alias_data};
}

=head2 Options hashref

This is passed through to the lower-level interface L<MediaWiki::API>, and is
fully documented there.

The hashref can have 3 keys:

=over 4

=item max

Specifies the maximum number of queries to retrieve data from the wiki. This is
independent of the I<size> of each query (how many items each query returns).
Set to 0 to retrieve all the results.

=item hook

Specifies a coderef to a hook function that can be used to process large lists
as they come in. When this is used, your subroutine will get the raw data. This
is noted in cases where it is known to be significant. For example, when
using a hook with C<top_edits()>, you need to check whether the edit is the top
edit yourself - your subroutine gets results as they come in, and before they're
filtered.

=item skip_encoding

MediaWiki's API uses UTF-8 and any 8 bit character string parameters are encoded
automatically by the API call. If your parameters are already in UTF-8 this will
be detected and the encoding will be skipped. If your parameters for some reason
contain UTF-8 data but no UTF-8 flag is set (i.e. you did not use the
C<< use L<utf8>; >> pragma) you should prevent re-encoding by passing an option
C<< skip_encoding => 1 >>. For example:

    $category ="Cat\x{e9}gorie:moyen_fran\x{e7}ais"; # latin1 string
    $bot->get_all_pages_in_category($category); # OK

    $category = "Cat". pack("U", 0xe9)."gorie:moyen_fran".pack("U",0xe7)."ais"; # unicode string
    $bot->get_all_pages_in_category($category); # OK

    $category ="Cat\x{c3}\x{a9}gorie:moyen_fran\x{c3}\x{a7}ais"; # unicode data without utf-8 flag
    # $bot->get_all_pages_in_category($category); # NOT OK
    $bot->get_all_pages_in_category($category, { skip_encoding => 1 }); # OK

If you need this, it probably means you're doing something wrong. Feel free to
ask for help.

=back

=head1 ERROR HANDLING

All functions will return undef in any handled error situation. Further error
data is stored in C<< $bot->{error}->{code} >> and C<< $bot->{error}->{details} >>.

Error codes are provided as constants in L<MediaWiki::Bot::Constants>, and can also
be imported through this module:

    use MediaWiki::Bot qw(:constants);

=cut

1;

#!/usr/bin/env perl

=head1 NAME

screenshot.pl - Take a screenshot

=head1 SYNOPSIS

screenshot.pl [OPTION]... [URI [FILE]]

    -h, --help             print this help message
    -t TYPE, --type TYPE   format type (svg, ps, pdf, png)

Simple usage:

    screenshot.pl --type svg http://www.google.com/

=head1 DESCRIPTION

Take a screenshot of a page.

=cut

use strict;
use warnings;

use Data::Dumper;
use Getopt::Long qw(:config auto_help);
use Pod::Usage;

use Glib::Object::Introspection;

Glib::Object::Introspection->setup(
  basename => 'Gtk',
  version  => '3.0',
  package  => 'Gtk3'
);

Glib::Object::Introspection->setup(
  basename => 'WebKit',
  version  => '3.0',
  package  => 'WebKit'
);
use Cairo::GObject;
use constant TRUE  => 1;
use constant FALSE => 0;

my %TYPES = (
    svg => sub { save_as_vector('Cairo::SvgSurface', @_) },
    ps  => sub { save_as_vector('Cairo::PsSurface', @_) },
    pdf => sub { save_as_vector('Cairo::PdfSurface', @_) },
    png => \&save_as_png,
);

sub main {
    Gtk3::init(0, []);

    GetOptions(
        't|type=s' => \my $type,
    ) or podusage(1);

    if ($type) {
        $type = lc $type;
        die "Type must be one of: ", join(", ", keys %TYPES) unless exists $TYPES{$type};
    }
    else {
        $type = 'pdf';
    }
    my $save_as_func = $TYPES{$type};

    my ($url, $filename) = @ARGV;
    $url ||= 'http://localhost:3001/';
    $filename ||= "screenshot.$type";

    my $view = WebKit::WebView->new();
    $view->signal_connect('notify::load-status' => sub {
        return unless $view->get_uri and ($view->get_load_status eq 'finished');

        printf "mapped? %s\n", $view->get_mapped ? 'YES' : 'NO';
        printf "visible? %s\n", $view->get_visible ? 'YES' : 'NO';
        printf "sensitive? %s\n", $view->is_sensitive ? 'YES' : 'NO';

        # Sometimes the program dies with:
        #  (<unknown>:19092): Gtk-CRITICAL **: gtk_widget_draw: assertion `!widget->priv->alloc_needed' failed
        # This seem to happend is there's a newtwork error and we can't download
        # external stuff (e.g. facebook iframe). This timeout seems to help a bit.
        Glib::Timeout->add(1000, sub {
            $save_as_func->($view, $filename);
            Gtk3->main_quit();
        });
    });
    $view->load_uri($url);


    my $window = Gtk3::OffscreenWindow->new();
    $window->add($view);
    $window->show_all();

    Gtk3->main();
    return 0;
}


sub save_as_vector {
    my ($surface_class, $widget, $filename) = @_;

    my ($width, $height) = ($widget->get_allocated_width, $widget->get_allocated_height);
    print "$filename has size: $width x $height\n";
    my $surface = $surface_class->create($filename, $width, $height);
    my $cr = Cairo::Context->create($surface);
    $widget->draw($cr);
}


sub save_as_png {
    my ($widget, $filename) = @_;

    my ($width, $height) = ($widget->get_allocated_width, $widget->get_allocated_height);
    print "$filename has size: $width x $height\n";
    my $surface = Cairo::ImageSurface->create(argb32 => $width, $height);
    my $cr = Cairo::Context->create($surface);
    $widget->draw($cr);
    $surface->write_to_png($filename);
}


exit main() unless caller;

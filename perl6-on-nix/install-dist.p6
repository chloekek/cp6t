#!/usr/bin/env perl6

# THIS FILE IS COPIED FROM https://github.com/rakudo/rakudo
# SEE LICENSE THERE
# TODO: Delete this file from the repo and get it using Nix.

=begin pod

This script is for installing Perl6 modules. B<install-dist.p6> does the same module registration like the 'zef' tool.

B<install-dist.p6> makes it easy to install a module system wide.

=head1 OPTIONS

By default the destination is the site of the Perl 6 library.

    # Install to a custom location
    --to=<destination>     # /home/username/my_perl6_mod_dir

If you specify a destination that does not exists then it will be created. The --to option can only be used together with the --for option.

    --for=[ vendor | site ]

    --from=<home of the module source>   # default is the current directory


The command in the install session for packaging a Perl 6 module could be done in the form:

    install-dist.p6 --to=<buildroot/...> --for=vendor

It is recommended to set the environment variable 'RAKUDO_RERESOLVE_DEPENDENCIES' by using the script:

    RAKUDO_RERESOLVE_DEPENDENCIES=0 install-dist.p6 --to=<buildroot/...> --for=site

=end pod


use v6.c;
use CompUnit::Repository::Staging;

# Distribution::Path ignores META.info files, but we can manually set it
sub find-meta-file($dir) {
    ('META6.json', 'META.info').map({$dir.child($_)}).first: {$_ ~~ :f}
}

multi sub MAIN(:from(:$dist-prefix) = '.', :to(:$repo-prefix)!, :for(:$repo-name)!) {
    my $meta-file = find-meta-file($dist-prefix.IO);
    my $dist      = Distribution::Path.new($dist-prefix.IO, :$meta-file);

    build(:dist-prefix($dist-prefix.IO));

    CompUnit::Repository::Staging.new(
        :prefix($repo-prefix),
        :next-repo(CompUnit::RepositoryRegistry.repository-for-name($repo-name)),
        :name($repo-name),
    ).install($dist);

    $_.unlink for <version repo.lock precomp/.lock>.map: {$repo-prefix.IO.child($_)};
}

multi sub MAIN(:from(:$dist-prefix) = '.', :to(:$repo-id) = 'site', Bool :$force) {
    my $meta-file = find-meta-file($dist-prefix.IO);
    my $dist      = Distribution::Path.new($dist-prefix.IO, :$meta-file);

    build(:dist-prefix($dist-prefix.IO));

    my $repo = first * ~~ CompUnit::Repository::Installable,
        CompUnit::RepositoryRegistry.repository-for-name($repo-id),
        CompUnit::RepositoryRegistry.repository-for-spec($repo-id)
            or die "Repository '$repo-id' is not an installable target";

    $repo.install($dist, :$force);
}

sub build(IO::Path :$dist-prefix) {
    my $meta-file = find-meta-file($dist-prefix);
    my $meta = Rakudo::Internals::JSON.from-json($meta-file.slurp);

    if ($meta<builder>) {
        my $builder-class =  first { .so },
            (try require ::("$meta<builder>")),
            (try require ::("Distribution::Builder::$meta<builder>")); # get rid of this hard-coded prefix variation eventually

        my $builder = $builder-class.new(:$meta);

        if $builder.can-build {
            $builder.build;
            exit;
        }
        else {
            note "Failed to build";
            exit 1;
        }
    }
}

# vim: ft=perl6

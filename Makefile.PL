use ExtUtils::MakeMaker;

use YAML::Any qw(LoadFile);
my $file = "addons/ConfigAssistant.pack/config.yaml";
my $version = LoadFile($file)->{version} ||
    die "No version found in $file";

WriteMakefile(
    NAME            => 'Config Assistant',
    VERSION         => $version,
    DISTNAME        => 'ConfigAssistant',
);

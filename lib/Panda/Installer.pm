class Panda::Installer {
use Panda::Common;
use Panda::Project;
use File::Find;
use Shell::Command;

has $.prefix = self.default-prefix();

method sort-lib-contents(@lib) {
    my @generated = @lib.grep({ $_ ~~  / \. <{compsuffix}> $/});
    my @rest = @lib.grep({ $_ !~~ / \. <{compsuffix}> $/});
    return flat @rest, @generated;
}

# default install location
method default-prefix {
    my $ret;
    for grep(*.defined, %*CUSTOM_LIB<site home>) -> $prefix {
#        $ret = CompUnitRepo.new("inst#$prefix");   # TEMPORARY !!!
        $ret = $prefix;
        last if $ret.IO.w;
    }
    return $ret;
}

sub copy($src, $dest) {
    note "Copying $src to $dest";
    unless $*DISTRO.is-win {
        $dest.IO.unlink;
    }
    $src.copy($dest);
}

method install($from, $to? is copy, Panda::Project :$bone) {
    unless $to {
        $to = $.prefix;
    }
    $to = $to.IO.absolute; # we're about to change cwd
    indir $from, {
        # check if $.prefix is under control of a CompUnitRepo
        if $to.can('install') {
            my @files;
            if 'blib'.IO ~~ :d {
                @files.append: find(dir => 'blib', type => 'file').list.grep( -> $lib {
                    next if $lib.basename.substr(0, 1) eq '.';
                    $lib
                } )
            }
            if 'bin'.IO ~~ :d {
                @files.append: find(dir => 'bin', type => 'file').list.grep( -> $bin {
                    next if $bin.basename.substr(0, 1) eq '.';
                    next if !$*DISTRO.is-win and $bin.basename ~~ /\.bat$/;
                    $bin
                } )
            }
            $to.install(:dist($bone), @files);
        }
        else {
            if 'blib'.IO ~~ :d {
                my @lib = find(dir => 'blib', type => 'file').list;
                for self.sort-lib-contents(@lib) -> $i {
                    next if $i.basename.substr(0, 1) eq '.';
                    # .substr(5) to skip 'blib/'
                    mkpath "$to/{$i.dirname.substr(5)}";
                    copy($i, "$to/{$i.substr(5)}");
                }
            }
            if 'bin'.IO ~~ :d {
                for find(dir => 'bin', type => 'file').list -> $bin {
                    next if $bin.basename.substr(0, 1) eq '.';
                    next if !$*DISTRO.is-win and $bin.basename ~~ /\.bat$/;
                    mkpath "$to/{$bin.dirname}";
                    copy($bin, "$to/$bin");
                    "$to/$bin".IO.chmod(0o755) unless $*DISTRO.is-win;

                    # TODO remove this once CompUnit installation actually works
                    "$to/$bin.bat".IO.spurt(q:to[SCRIPT]
@rem = '--*-Perl-*--
@echo off
if "%OS%" == "Windows_NT" goto WinNT
perl6 "%~dpn0" %1 %2 %3 %4 %5 %6 %7 %8 %9
goto endofperl
:WinNT
perl6 "%~dpn0" %*
if NOT "%COMSPEC%" == "%SystemRoot%\system32\cmd.exe" goto endofperl
if %errorlevel% == 9009 echo You do not have Perl in your PATH.
if errorlevel 1 goto script_failed_so_exit_with_non_zero_val 2>nul
goto endofperl
@rem ';
__END__
:endofperl
SCRIPT
                    );
                }
            }
        }
        1;
    }
}

}

# vim: ft=perl6

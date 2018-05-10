#!/bin/bash
# vim: dict=/usr/share/beakerlib/dictionary.vim cpt=.,w,b,u,t,i,k
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   runtest.sh of /tools/libffi/Sanity/testsuite
#   Description: Runs upstream testsuite
#   Author: Michal Nowak <mnowak@redhat.com>
#
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   Copyright (c) 2010 Red Hat, Inc. 
#
#   This program is free software: you can redistribute it and/or
#   modify it under the terms of the GNU General Public License as
#   published by the Free Software Foundation, either version 3 of
#   the License, or (at your option) any later version.
#
#   This program is distributed in the hope that it will be
#   useful, but WITHOUT ANY WARRANTY; without even the implied
#   warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR
#   PURPOSE.  See the GNU General Public License for more details.
#
#   You should have received a copy of the GNU General Public License
#   along with this program. If not, see http://www.gnu.org/licenses/.
#
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

# Include rhts environment
. /usr/lib/beakerlib/beakerlib.sh

PACKAGES=(libffi libffi-devel gcc dejagnu rpm-build gcc-c++)

rlJournalStart
    rlPhaseStartSetup
        for p in "${PACKAGES[@]}"; do
            if ! rlCheckRpm "$p"; then
                rlRun "yum -y install $p"
                rlAssertRpm "$p"
            fi
        done;

        rlRun "TmpDir=`mktemp -d`" 0 "Creating tmp directory"
        rlRun "cp *.patch $TmpDir/"
        rlRun "pushd $TmpDir"
        rlFetchSrcForInstalled libffi
        rlRun "rpm -ivh libffi*.src.rpm"
        rlRun "popd"
        rlRun "specfile=$(rpm --eval='%_specdir')/libffi.spec"
        rlRun "rpmbuild -bp $specfile"
        rlRun "builddir=$(rpm --eval='%_builddir')"
        rlRun "pushd $builddir/libffi-*/"
        rlRun "./configure"
        rlRUn "make"
    rlPhaseEnd

    rlPhaseStartTest "Run testsuite"

        # patching the testsuite to test the installed libraries instead of the built ones
        if [ -e /usr/lib64/libffi.so ]; then
            export LD_LIBRARY_PATH=/usr/lib64
            perl -i -pe 's/LIBRARY_DIR/lib64/' $TmpDir/dynamic_linking.patch
            perl -i -pe 's/LIBRARY_DIR/lib64/' $TmpDir/dynamic_linking-dg.patch
        else
            export LD_LIBRARY_PATH=/usr/lib
            perl -i -pe 's/LIBRARY_DIR/lib/' $TmpDir/dynamic_linking.patch
            perl -i -pe 's/LIBRARY_DIR/lib/' $TmpDir/dynamic_linking-dg.patch
        fi
        test -e testsuite/lib/libffi.exp && rlRun "patch testsuite/lib/libffi.exp < $TmpDir/dynamic_linking.patch"
        test -e testsuite/lib/libffi-dg.exp && rlRun "patch testsuite/lib/libffi-dg.exp < $TmpDir/dynamic_linking-dg.patch"
        rlLog "Checking whether we test really the installed libraries."
        strace -F -e open,openat,stat -o strace.log -- make check
        LIBFFI_SO_CALLS=`cat strace.log | grep libffi.so | grep -v ENOENT | grep -v 'usr/lib' | grep -v '\"\/lib' | grep -v 'unfinished' | wc -l`
        rlAssertGreater "The just built libraries should not be used, everything should be taken from /usr" 5 $LIBFFI_SO_CALLS
        rlRun "cat strace.log | grep libffi.so | grep usr"
        rlRun "cat strace.log | grep libffi.so | grep rpmbuild" 1
        rlRun "make check" 0 "RUNNING THE TESTSUITE"
        rlRun "popd"
    rlPhaseEnd

    rlPhaseStartCleanup
        rlRun "ls -al $TmpDir"
        rlBundleLogs logs $(find . -name 'libffi.sum') $(find . -name 'libffi.log')
        rlRun "rm -r $TmpDir" 0 "Removing tmp directory"
    rlPhaseEnd
rlJournalPrintText
rlJournalEnd

Name:		legovid2dvd
Version:	0.0.2
Release:	1%{?dist}
Summary:	LEGO� video downloader and DVD authoring tool

Group:		Applications/Internet
License:	GPLv2
URL:		https://github.com/bdperkin/%{name}
Source0:	https://github.com/bdperkin/%{name}/sources/%{name}-%{version}.tar.gz

BuildArch:	noarch
BuildRequires:	asciidoc
BuildRequires:	docbook-style-xsl
BuildRequires:	/usr/bin/groff
BuildRequires:	libxslt
BuildRequires:	pandoc
BuildRequires:	/usr/bin/perltidy
BuildRequires:	/usr/bin/podchecker
BuildRequires:	w3m
Requires:	/usr/bin/perl
Requires:	/usr/bin/perldoc
Requires:	perl(Getopt::Long)
Requires:	perl(WWW::Curl::Easy)
Requires:	perl(XML::XPath)
Requires:	perl(strict)
Requires:	perl(warnings)

%define NameUpper %{expand:%%(echo %{name} | tr [:lower:] [:upper:])}
%define NameMixed %{expand:%%(echo %{name} | %{__sed} -e "s/\\([a-z]\\)\\([a-zA-Z0-9]*\\)/\\u\\1\\2/g")}
%define NameLower %{expand:%%(echo %{name} | tr [:upper:] [:lower:])}
%define Year %{expand:%%(date "+%Y")}
%define DocFiles ACKNOWLEDGEMENTS AUTHOR AUTHORS AVAILABILITY BUGS CAVEATS COPYING COPYRIGHT DESCRIPTION FILTERS LICENSE NAME NOTES OPTIONS OUTPUT README.md RESOURCES SYNOPSIS
%define SubFiles %{name} %{name}.8.asciidoc %{DocFiles} man.asciidoc
%define DocFormats chunked htmlhelp manpage text xhtml

%description
Perl script to download LEGO� videos, convert them, and author a DVD.

%prep
%setup -q

%clean
%{__rm} -rf $RPM_BUILD_ROOT

%build
%{__cp} %{name}.pl %{name}
%{__sed} -i -e s/%{NAME}/%{name}/g %{SubFiles}
%{__sed} -i -e s/%{NAMEUPPER}/%{NameUpper}/g %{SubFiles}
%{__sed} -i -e s/%{NAMEMIXED}/%{NameMixed}/g %{SubFiles}
%{__sed} -i -e s/%{NAMELOWER}/%{NameLower}/g %{SubFiles}
%{__sed} -i -e s/%{VERSION}/%{version}/g %{SubFiles}
%{__sed} -i -e s/%{RELEASE}/%{release}/g %{SubFiles}
%{__sed} -i -e s/%{YEAR}/%{Year}/g %{SubFiles}
for f in %{DocFormats}; do %{__mkdir_p} $f; a2x -D $f -d manpage -f $f %{name}.8.asciidoc; done
groff -e -mandoc -Tascii manpage/%{name}.8 > manpage/%{name}.8.groff
%{__mkdir_p} pod
./groff2pod.pl manpage/%{name}.8.groff pod/%{name}.8.pod
podchecker pod/%{name}.8.pod
cat pod/%{name}.8.pod >> %{name}
perltidy -b %{name}
podchecker %{name}
pandoc -f html -t markdown -s -o README.md.pandoc xhtml/%{name}.8.html
cat README.md.pandoc | %{__grep} -v ^% | %{__sed} -e 's/\*\*/\*/g' | %{__sed} -e 's/^\ \*/\n\ \*/g' | %{__sed} -e 's/\[\*/\[\ \*/g' | %{__sed} -e 's/\*\]/\*\ \]/g' | %{__sed} -e 's/{\*/{\ \*/g' | %{__sed} -e 's/\*}/\*\ }/g' | %{__sed} -e 's/|\*/|\ \*/g' | %{__sed} -e 's/\*|/\*\ |/g' | %{__sed} -e 's/=\*/=\ \*/g' | %{__sed} -e 's/\*=/\*\ =/g' > README.md 

%install
%{__rm} -rf $RPM_BUILD_ROOT
%{__mkdir_p} %{buildroot}%{_bindir}
%{__mkdir_p} %{buildroot}%{_mandir}/man8
%{__install} %{name} %{buildroot}%{_bindir}
%{__gzip} -c manpage/%{name}.8 > %{buildroot}/%{_mandir}/man8/%{name}.8.gz

%files
%defattr(-,root,root,-)
%{_bindir}/%{name}
%doc %{DocFiles}
%doc %{DocFormats} pod
%doc %{_mandir}/man8/%{name}.8.gz


%changelog
* Tue Apr 08 2014 Brandon Perkins <bperkins@redhat.com> 0.0.2-1
- new package built with tito


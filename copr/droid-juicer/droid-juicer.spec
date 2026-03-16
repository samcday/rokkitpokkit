%bcond check 1

%global crate droid-juicer
%global commit fcdd658a66428f296bcf0e12e94b5d1ac5bcb511

Name:           %{crate}
Version:        0.4.2
Release:        0.1.%{commit}%{?dist}
Summary:        Extract firmware from Android vendor partitions

License:        MIT
URL:            https://github.com/samcday/%{crate}
Source0:        %{url}/archive/%{commit}/%{crate}-%{commit}.tar.gz

BuildRequires:  cargo-rpm-macros >= 24
BuildRequires:  systemd-rpm-macros

Requires(post): systemd
Requires(preun): systemd
Requires(postun): systemd

%description
droid-juicer extracts binary firmware from Android vendor partitions and
installs it into /lib/firmware, avoiding redistributing vendor blobs.

%post
%systemd_post droid-juicer.service

%preun
%systemd_preun droid-juicer.service

%postun
%systemd_postun_with_restart droid-juicer.service

%prep
%autosetup -n %{crate}-%{commit} -p1
%cargo_prep

%generate_buildrequires
%cargo_generate_buildrequires

%build
%cargo_build
%{cargo_license_summary}
%{cargo_license} > LICENSE.dependencies

%install
%cargo_install
install -Dpm 0644 droid-juicer.service %{buildroot}%{_unitdir}/droid-juicer.service
mkdir -p %{buildroot}%{_sysconfdir}/droid-juicer %{buildroot}%{_datadir}/droid-juicer/configs/
install -Dpm 0644 configs/*.toml %{buildroot}%{_datadir}/droid-juicer/configs/

%if %{with check}
%check
%cargo_test
%endif

%files
%license LICENSE
%license LICENSE.dependencies
%doc README.md
%{_bindir}/droid-juicer
%dir %{_sysconfdir}/droid-juicer
%{_unitdir}/droid-juicer.service
%dir %{_datadir}/droid-juicer
%dir %{_datadir}/droid-juicer/configs
%{_datadir}/droid-juicer/configs/*.toml

%changelog
* Tue Mar 17 2026 Sam Day <me@samcday.com> - 0.4.2-0.1.fcdd658a66428f296bcf0e12e94b5d1ac5bcb511
- Build from samcday/droid-juicer GitHub main HEAD snapshot.

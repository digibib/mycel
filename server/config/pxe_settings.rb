module PXESettings
  #
  # PXE settings
  # for booting clients via PixieCore in API mode.
  #
  # To confirm parameters, 'cat /proc/cmdline' on client
  # resources: https://github.com/danderson/pixiecore/blob/master/README.api.md
  #


  PXE_WORKSTATION = {
    :kernel =>   'file:/boot/mounts/mycelimage/casper/vmlinuz',
    :initrd =>   ['file:/boot/mounts/mycelimage/casper/initrd.gz'],

    :cmdline =>  'root=/dev/nfs boot=casper netboot=nfs nfsroot=xxxxxxx:/srv/nfs/mycelimage
                  splash quiet noacpi pci=noacpi acpi=force',
    :message  => 'Booter langtidsstasjon'}


  PXE_TEST_WORKSTATION = {
    :kernel =>   'file:/srv/nfs/mycelimage/casper/vmlinuz',
    :initrd =>   ['file:/srv/nfs/mycelimage/casper/initrd.gz'],

    :cmdline =>  {:root => '/dev/nfs',
                  :boot => 'casper',
                  :netboot => 'nfs',
                  :nfsroot => '10.172.3.16:/srv/nfs/mycelimage',
                  :splash => true, :quiet => true, :noacpi => true,
                  :pci => 'noacpi', :acpi => 'force'},
    :message  => 'Booter langtidsstasjon test'}

  PXE_SEARCHSTATION = {
    :kernel =>   'file:/boot/mounts/mycelimage/casper/vmlinuz',
    :initrd =>   ['file:/boot/mounts/mycelimage/casper/initrd.gz'],

    :cmdline =>  'root=/dev/nfs boot=casper netboot=nfs nfsroot=xxxxxx:/srv/nfs/mycelimage
                  splash quiet noacpi pci=noacpi acpi=force',
    :message  => 'Booter sokestasjon'}

  PXE_TEST_SEARCHSTATION = {
    :kernel =>   'file:/boot/mounts/mycelimage/casper/vmlinuz',
    :initrd =>   ['file:/boot/mounts/mycelimage/casper/initrd.gz'],

    :cmdline =>  'root=/dev/nfs boot=casper netboot=nfs nfsroot=xxxxxx:/srv/nfs/mycelimage
                  splash quiet noacpi pci=noacpi acpi=force',
    :message  => 'Booter sokestasjon test'}


  PXE_UNREGISTERED_CLIENT = {
    :kernel =>   "file:/home/osboxes/share/LICENSE",
    :initrd =>   ['file://home/osboxes/share/'],
    :cmdline => {},
    :message  =>
    "
    Klienten er ikke registrert i systemet.
    Kontakt administrator og oppgi referansenummer %{referenceID}

    " }

end

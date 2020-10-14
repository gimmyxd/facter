# frozen_string_literal: true

module Facter
  module OsConfig
    HIERARCHY = [
      {
        "Linux": [
          {
            "Debian": %w[
              Elementary
              Ubuntu
              Raspbian
            ]
          },
          {
            "Rhel": %w[
              Fedora
              Amzn
              Centos
              Ol
              Scientific
            ]
          },
          {
            "Sles": [
              'Opensuse'
            ]
          }
        ]
      },
      {
        "Bsd": [
          'Freebsd'
        ]
      },
      'Solaris',
      'Macosx',
      'Windows',
      'Aix'
    ].freeze unless defined?(HIERARCHY)
  end
end

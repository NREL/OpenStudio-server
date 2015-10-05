name 'r-project'
description 'install r'

default_attributes(
  r: {
    version: '3.2.2',
    checksum: '9c9152e74134b68b0f3a1c7083764adc1cb56fd8336bec003fd0ca550cd2461d',
    install_repo: false,
    install_method: 'source',
    add_r_to_path: true,
    add_ld_path: true,
    prefix_bin: '/usr/local/bin',
    make_opts: ['-j4'],
    r_environment_site: {
      rubylib: '/usr/local/lib/site_ruby/2.0.0',
      path_additions: ['/usr/local/radiance/bin', '/opt/rbenv/shims']
    },
    libraries: [
      {
        name: 'Rserve',
        configure_flags: 'PKG_CPPFLAGS=-DNODAEMON'
      },
      {
        name: 'lhs'
      },
      {
        name: 'e1071'
      },
      {
        name: 'triangle'
      },
      {
        name: 'rJava'
      },
      {
        name: 'RUnit'
      },
      {
        name: 'RMongo'
      },
      {
        name: 'R.methodsS3'
      },
      {
        name: 'R.oo'
      },
      {
        name: 'R.utils'
      },
      {
        name: 'NMOF'
      },
      {
        name: 'mco'
      },
      {
        name: 'rjson'
      },
      {
        name: 'rgenoud'
      },
      {
        name: 'conf.design'
      },
      {
        name: 'vcd'
      },
      {
        name: 'combinat'
      },
      {
        name: 'DoE.base'
      },
      {
        name: 'NRELmoo',
        package_path: '/data/R-packages',
        version: '1.2.23',
        update_method: 'always_update'
      },
      {
        name: 'nrelPSO',
        package_path: '/data/R-packages',
        version: '0.3-4',
        update_method: 'always_update'
      },
      {
        name: 'xts'
      },
      {
        name: 'RSQLite'
      },
      {
        name: 'Rcpp'
      },
      {
        name: 'plyr'
      },
      {
        name: 'ggplot2'
      }
    ]
  }
)

override_attributes(
  r: {
    config_opts: ['--enable-R-shlib'] # build with x11 support (removes "--with-x=no",)
  }
)

run_list(
  [
    'recipe[r::default]',
    'recipe[r::rserve]'
  ])

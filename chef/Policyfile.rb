name 'gladstone'
default_source :supermarket
run_list 'recipe[gladstone_base::default]'
cookbook 'gladstone_base', path: './cookbooks/gladstone_base'
cookbook 'gladstone_hub', path: './cookbooks/gladstone_hub'
cookbook 'gladstone_webhost', path: './cookbooks/gladstone_webhost'

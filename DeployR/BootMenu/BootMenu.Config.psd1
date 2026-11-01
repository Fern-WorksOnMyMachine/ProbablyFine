<#
Public sample configuration for the DeployR Boot Menu.
Replace the sample values with values that match your own task sequence.
Variable names are written directly to TSEnv.
#>
@{
    Settings = @{
        WindowTitle = 'DeployR Provisioning Center - 2Pint Software'
        MenuTitle = 'DeployR Boot Menu'
        TimeZone = 'W. Europe Standard Time'
        OemPassword = 'Password'
        OemBackValue = 'BACK'
    }

    Sites = @(
        @{
            Name = 'Site 1'
            Pattern = '192.0.2.*'
        }
        @{
            Name = 'Site 2'
            Pattern = '198.51.100.*'
        }
    )

    Municipalities = @(
        @{
            Name = 'Customer 1'
            Roles = @(
                @{
                    Name = 'Role 1'
                    Code = 'CUSTOMER1-ROLE1'
                    Variables = @{
                        Kommmunroll = 'CUSTOMER1-ROLE1'
                        F12Target = 'Role1'
                        F12Image = 'ExampleImage1'
                        F12Role = 'Role 1 - Customer 1'
                        KommunrollBlock = 'CUSTOMER1'
                        Tenant = 'EXAMPLE'
                    }
                    PhysicalVariables = @{
                        GROUPTAG = 'CUSTOMER1-ROLE1-PHYSICAL'
                    }
                    VMVariables = @{
                        GROUPTAG = 'CUSTOMER1-ROLE1-VM'
                        VMRoleType = 'CUSTOMER1-ROLE1-PHYSICAL'
                    }
                    RequiresOemPassword = $false
                    Profile = @{
                        Title = 'Role 1'
                        DescriptionLines = @(
                            'Example deployment role for Customer 1.'
                            ''
                            '- Replace these example values'
                            '- Add the required task sequence variables'
                            '- Review all values before production use'
                        )
                        AccentColor = '93,210,255'
                    }
                }
                @{
                    Name = 'Role 2'
                    Code = 'CUSTOMER1-ROLE2'
                    Variables = @{
                        Kommmunroll = 'CUSTOMER1-ROLE2'
                        F12Target = 'Role2'
                        F12Image = 'ExampleImage2'
                        F12Role = 'Role 2 - Customer 1'
                        KommunrollBlock = 'CUSTOMER1'
                        Tenant = 'EXAMPLE'
                    }
                    PhysicalVariables = @{
                        GROUPTAG = 'CUSTOMER1-ROLE2-PHYSICAL'
                    }
                    VMVariables = @{
                        GROUPTAG = 'CUSTOMER1-ROLE2-VM'
                        VMRoleType = 'CUSTOMER1-ROLE2-PHYSICAL'
                    }
                    RequiresOemPassword = $true
                    Profile = @{
                        Title = 'Role 2 - Password protected'
                        DescriptionLines = @(
                            'Example password-protected deployment role.'
                            ''
                            '- Sample password: Password'
                            '- Change the password before production use'
                            '- Replace all example task sequence values'
                        )
                        AccentColor = '255,174,66'
                    }
                }
            )
        }
        @{
            Name = 'Customer 2'
            Roles = @(
                @{
                    Name = 'Role 1'
                    Code = 'CUSTOMER2-ROLE1'
                    Variables = @{
                        Kommmunroll = 'CUSTOMER2-ROLE1'
                        F12Target = 'Role1'
                        F12Image = 'ExampleImage1'
                        F12Role = 'Role 1 - Customer 2'
                        KommunrollBlock = 'CUSTOMER2'
                        Tenant = 'EXAMPLE'
                    }
                    PhysicalVariables = @{
                        GROUPTAG = 'CUSTOMER2-ROLE1-PHYSICAL'
                    }
                    VMVariables = @{
                        GROUPTAG = 'CUSTOMER2-ROLE1-VM'
                        VMRoleType = 'CUSTOMER2-ROLE1-PHYSICAL'
                    }
                    RequiresOemPassword = $false
                    Profile = @{
                        Title = 'Role 1'
                        DescriptionLines = @(
                            'Example deployment role for Customer 2.'
                            ''
                            '- Replace these example values'
                            '- Add the required task sequence variables'
                            '- Review all values before production use'
                        )
                        AccentColor = '110,161,255'
                    }
                }
                @{
                    Name = 'Role 2'
                    Code = 'CUSTOMER2-ROLE2'
                    Variables = @{
                        Kommmunroll = 'CUSTOMER2-ROLE2'
                        F12Target = 'Role2'
                        F12Image = 'ExampleImage2'
                        F12Role = 'Role 2 - Customer 2'
                        KommunrollBlock = 'CUSTOMER2'
                        Tenant = 'EXAMPLE'
                    }
                    PhysicalVariables = @{
                        GROUPTAG = 'CUSTOMER2-ROLE2-PHYSICAL'
                    }
                    VMVariables = @{
                        GROUPTAG = 'CUSTOMER2-ROLE2-VM'
                        VMRoleType = 'CUSTOMER2-ROLE2-PHYSICAL'
                    }
                    RequiresOemPassword = $true
                    Profile = @{
                        Title = 'Role 2 - Password protected'
                        DescriptionLines = @(
                            'Example password-protected deployment role.'
                            ''
                            '- Sample password: Password'
                            '- Change the password before production use'
                            '- Replace all example task sequence values'
                        )
                        AccentColor = '255,174,66'
                    }
                }
            )
        }
    )
}

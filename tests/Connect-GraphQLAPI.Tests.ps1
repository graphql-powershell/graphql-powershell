
Remove-Module -Name 'powershell-graphql-interface' -ErrorAction 'SilentlyContinue'
Import-Module -Name '../powershell-graphql-interface.psd1' -Force


Describe 'Connect-GraphQLAPI' {
    Context -Name "Parameter Validation" {
        It 'Fails with no Parameters' -Test {
            { Connect-GraphQLAPI -name '' } | 
            Should -Throw "Cannot bind argument to parameter 'Name' because it is an empty string."
        }
    }

}
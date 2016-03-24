Feature: Export build system
  As a programmer using reggae to generate a build system
  I want to export that build system for others to use
  So they don't have to install reggae

  Background:
    Given a file named "project/hello.d" with:
    """
    import std.stdio;
    void main() { writeln(`Hello world!`); }
    """
    And a file named "project/reggaefile.d" with:
    """
    import reggae;
    mixin build!(scriptlike!(App(SourceFileName(`hello.d`))));
    """
    And I successfully run `reggae --export project`

  @ninja
  Scenario: Exporting the build system with ninja
    Given I successfully run `ninja`
    When I successfully run `./hello`
    Then the output should contain:
    """
    Hello world!
    """
    And I successfully run `rm -rf hello objs`

  @make
  Scenario: Exporting the build system with make
    Given I successfully run `make`
    When I successfully run `./hello`
    Then the output should contain:
    """
    Hello world!
    """
    And I successfully run `rm -rf hello objs`

  @tup
  Scenario: Exporting the build system with tup
    Given I successfully run `tup`
    When I successfully run `./hello`
    Then the output should contain:
    """
    Hello world!
    """
    And I successfully run `rm -rf hello objs`
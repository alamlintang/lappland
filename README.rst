lappland - diceware generator
=============================
lappland is a dead simple diceware generator used to create a unique yet strong
diceware passphrase in a reproducible manner.

Requirements
------------
In order to build lappland, you will need the following:

* ``zig``
* ``argon2``

Installation
------------
To build from source, enter the following command::

  zig build install -Drelease-fast

The compiled binary will be saved in ``./zig-cache/bin``.

Usage
-----
Using lappland requires an user name and a website name. In practice however
these can be anything you want.

It also requires a master password, which is read from the standard input::

  echo -n "mypassword" | lapp davenull@example.com mail.example.com

The master password has no character limit and can be literally anything,
including a binary file::

  lapp "Foo Bar" example.com < /path/to/binary.exe

The resulting diceware passphrase is sent to the standard output. If redirected,
the trailing newline character is not appended::

  echo -n "texaslove123" | lapp Lappland penguin.gov.ri | xclip

See the man page for additional details.

License
-------
lappland is licensed under MIT License. See LICENSE for more details.

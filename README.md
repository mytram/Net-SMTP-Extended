Net-SMTP-Extended
=================

A SMTP client that fully supports the Net::SMTP interface and the
features that are part of Extended SMTP.

This incentive is to have a client that supports opportunistic and
forced TLS, and at the same time it still fully supports the Net::SMTP
interface, by inheritance. The current modules that support TLS either
only supports force TLS or are implemented by partially mimicking the
Net::SMTP interface, which will not be a drop-in replacement for
Net::SMTP so as not to cause too much change in current applications.


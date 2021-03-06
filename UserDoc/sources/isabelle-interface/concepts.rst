

========
Concepts
========

This document describes a |Specware| interface that allows the use of
the |IsabelleHOL| theorem prover to discharge proof obligations that
arise in developing |Specware| specifications. The interface is
essentially just a Specware Shell command and an Emacs command that
converts a |Specware| spec to an |Isabelle| theory, along with
extensions in the |Specware| syntax to allow |Isabelle| proof scripts
to be embedded in |Specware| specs, and to allow the user to specify
translation of |Specware| ops and types to existing |Isabelle|
constants and types. The translation translates |Specware|
declarations, definitions, axioms and theorems to the corresponding
|Isabelle| versions. The logics are similar, so it is usually
straightforward to compare the source and target of the
translations. In addition, |Specware| has implicit type obligations,
particularly sub-type obligations, that are explicated in the
|Isabelle| target.

We assume the user is familiar with |IsabelleHOL|. See the tutorial at
http://isabelle.in.tum.de/documentation.html.
The current version of the Isabelle translator works with Isabelle2013-2.
An example Specware spec with Isabelle proofs is given in 
``Examples/IsabelleInterface/BoolEx.sw``. This spec corresponds to the
Isabelle theory in section 2.2.4 of the |IsabelleHOL| tutorial.

.. COMMENT: As another example, the proof obligations of the specs in
            ``Examples/Matching/MatchingSpecs.sw`` can be translated and proved by
            |Isabelle| without any user annotation. 

To see examples of how to specify translation of |Specware| types and
ops to existing |Isabelle| types and constants, see the bottom of the
|Specware| Base library specs such as ``Library/Base/Integer.sw`` or
``Library/Base/List.sw``.

A |Specware| definition may translate into one of four different kinds
of Isabelle definitions: ``defs``\ , ``recdefs`` and the newer
``funs`` and ``functions``\ . Simple recursion on coproduct
constructors translates to ``fun``\ , but more complicated recursion
is usually translated to ``fun``\ . Some recursion still translates to
``recdef`` because the ``fun`` and ``function`` support is new, but
the user can force translation to ``function``\ . Non-recursive
functions are translated to ``defs``\ , except in some cases they are
translated to ``fun`` which allows more pattern matching.

The main difference in the logics of |Specware| and |IsabelleHOL| is
that |Specware| has predicate sub-types. In most cases a sub-type is
translated to its super-type and translations of quantifications over
a sub-type introduce an explicit application of the sub-type
predicate. A subtlety is that we need to consider the case that
polymorphic type variables may be instantiated with subtypes. When
necessary, e.g., for a predicate like ``injective?``\ , a single op is
translated to two |Isabelle| ops, the ordinary one and one with an
extra argument for a predicate or predicates corresponding to subtype
predicates for type variables. Another subtlety is with respect to
equality of functions with subtype domains. These are translated to
|Isabelle| functions with expanded domains, but to preserve equality
these are regularized to have a single value outside the restricted
domain. This regularization is not needed if the function is applied
to an argument, because it may only be applied to an argument for
which the predicate holds, so in some cases we do the regularization
lazily, i.e., give the function its unregularized definition, but
regularize it in contexts where it may be used in an equality.

There is a capability for translating a sub-type differently from its
super-type. This is used for the type ``Nat`` which is translated to
``nat`` rather than ``int``\ . In general, this may lead to coercions
between ``nat`` and ``int`` being inserted.

This initial translator has a few limitations. It should translate all
|Specware| specs but not all translated definitions and constructs
will be accepted by |IsabelleHOL|. In particular, only case
expressions that involve a single level of pattern-matching on
constructors are accepted. An exception is that nesting is allowed in
top-level case expressions that are converted into definition cases.


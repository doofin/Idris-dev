module Interfaces.Verified

import Control.Algebra
import Control.Algebra.Lattice
import Control.Algebra.NumericImplementations
import Control.Algebra.VectorSpace
import Data.Vect
import Data.ZZ

%default total
%access public export

-- Due to these being basically unused and difficult to implement,
-- they're in contrib for a bit. Once a design is found that lets them
-- be implemented for a number of implementations, and we get those
-- implementations, then some of them can move back to base (or even
-- prelude, in the cases of Functor, Applicative, Monad, Semigroup,
-- and Monoid).

interface Functor f => VerifiedFunctor (f : Type -> Type) where
  functorIdentity : {a : Type} -> (g : a -> a) -> ((v : a) -> g v = v) -> (x : f a) -> map g x = x
  functorComposition : {a : Type} -> {b : Type} -> (x : f a) ->
                       (g1 : a -> b) -> (g2 : b -> c) ->
                       map (g2 . g1) x = (map g2 . map g1) x

functorIdentity' : VerifiedFunctor f => (x : f a) -> map Basics.id x = x
functorIdentity' {f} = functorIdentity {f} id (\x => Refl)

VerifiedFunctor (Pair a) where
  functorIdentity g p (a,b) = rewrite p b in Refl
  functorComposition (a,b) g1 g2 = Refl

VerifiedFunctor Maybe where
  functorIdentity _ _ Nothing = Refl
  functorIdentity g p (Just x) = rewrite p x in Refl
  functorComposition Nothing g1 g2 = Refl
  functorComposition (Just x) g1 g2 = Refl

VerifiedFunctor (Vect n) where
  functorIdentity _ _ [] = Refl
  functorIdentity g p (x :: xs) = rewrite p x in cong (functorIdentity g p xs)
  functorComposition [] _ _ = Refl
  functorComposition (x :: xs) f g = rewrite functorComposition xs f g in Refl

interface (Applicative f, VerifiedFunctor f) => VerifiedApplicative (f : Type -> Type) where
  applicativeMap : (x : f a) -> (g : a -> b) ->
                   map g x = pure g <*> x
  applicativeIdentity : (x : f a) -> pure Basics.id <*> x = x
  applicativeComposition : (x : f a) -> (g1 : f (a -> b)) -> (g2 : f (b -> c)) ->
                           ((pure (.) <*> g2) <*> g1) <*> x = g2 <*> (g1 <*> x)
  applicativeHomomorphism : (x : a) -> (g : a -> b) ->
                            (<*>) {f} (pure g) (pure x) = pure {f} (g x)
  applicativeInterchange : (x : a) -> (g : f (a -> b)) ->
                           g <*> pure x = pure (\g' : (a -> b) => g' x) <*> g

VerifiedApplicative (Vect n) where
  applicativeMap [] f = Refl
  applicativeMap (x :: xs) f = rewrite applicativeMap xs f in Refl
  applicativeIdentity xs = rewrite sym $ applicativeMap xs id in functorIdentity' xs
  applicativeComposition [] [] [] = Refl
  applicativeComposition (x :: xs) (f :: fs) (g :: gs) = rewrite applicativeComposition xs fs gs in Refl
  applicativeHomomorphism = prf
    where prf : with Vect ((x : a) -> (f : a -> b) -> zipWith Basics.apply (replicate m f) (replicate m x) = replicate m (f x))
          prf {m = Z} x f = Refl
          prf {m = S k} x f = rewrite prf {m = k} x f in Refl
  applicativeInterchange = prf
    where prf : with Vect ((x : a) -> (f : Vect m (a -> b)) -> zipWith Basics.apply f (replicate m x) = zipWith Basics.apply (replicate m (\f' => f' x)) f)
          prf {m = Z} x [] = Refl
          prf {m = S k} x (f :: fs) = rewrite prf x fs in Refl

VerifiedApplicative Maybe where
  applicativeMap Nothing g = Refl
  applicativeMap (Just x) g = Refl
  applicativeIdentity Nothing = Refl
  applicativeIdentity (Just x) = Refl
  applicativeComposition Nothing Nothing Nothing = Refl
  applicativeComposition Nothing Nothing (Just x) = Refl
  applicativeComposition Nothing (Just x) Nothing = Refl
  applicativeComposition Nothing (Just x) (Just y) = Refl
  applicativeComposition (Just x) Nothing Nothing = Refl
  applicativeComposition (Just x) Nothing (Just y) = Refl
  applicativeComposition (Just x) (Just y) Nothing = Refl
  applicativeComposition (Just x) (Just y) (Just z) = Refl
  applicativeHomomorphism x g = Refl
  applicativeInterchange x Nothing = Refl
  applicativeInterchange x (Just y) = Refl

interface (Monad m, VerifiedApplicative m) => VerifiedMonad (m : Type -> Type) where
  monadApplicative : (mf : m (a -> b)) -> (mx : m a) ->
                     mf <*> mx = mf >>= \f =>
                                 mx >>= \x =>
                                        pure (f x)
  monadLeftIdentity : (x : a) -> (f : a -> m b) -> pure x >>= f = f x
  monadRightIdentity : (mx : m a) -> mx >>= Applicative.pure = mx
  monadAssociativity : (mx : m a) -> (f : a -> m b) -> (g : b -> m c) ->
                       (mx >>= f) >>= g = mx >>= (\x => f x >>= g)

VerifiedMonad Maybe where
    monadApplicative Nothing Nothing = Refl
    monadApplicative Nothing (Just x) = Refl
    monadApplicative (Just x) Nothing = Refl
    monadApplicative (Just x) (Just y) = Refl
    monadLeftIdentity x f = Refl
    monadRightIdentity Nothing = Refl
    monadRightIdentity (Just x) = Refl
    monadAssociativity Nothing f g = Refl
    monadAssociativity (Just x) f g = Refl

interface Semigroup a => VerifiedSemigroup a where
  semigroupOpIsAssociative : (l, c, r : a) -> l <+> (c <+> r) = (l <+> c) <+> r

implementation VerifiedSemigroup (List a) where
  semigroupOpIsAssociative = appendAssociative

[PlusNatSemiV] VerifiedSemigroup Nat using PlusNatSemi where
  semigroupOpIsAssociative = plusAssociative

[MultNatSemiV] VerifiedSemigroup Nat using MultNatSemi where
  semigroupOpIsAssociative = multAssociative

[PlusZZSemiV] VerifiedSemigroup ZZ using PlusZZSemi where
  semigroupOpIsAssociative = plusAssociativeZ

[MultZZSemiV] VerifiedSemigroup ZZ using MultZZSemi where
  semigroupOpIsAssociative = multAssociativeZ

interface (VerifiedSemigroup a, Monoid a) => VerifiedMonoid a where
  monoidNeutralIsNeutralL : (l : a) -> l <+> Algebra.neutral = l
  monoidNeutralIsNeutralR : (r : a) -> Algebra.neutral <+> r = r

[PlusNatMonoidV] VerifiedMonoid Nat using PlusNatSemiV, PlusNatMonoid where
   monoidNeutralIsNeutralL = plusZeroRightNeutral
   monoidNeutralIsNeutralR = plusZeroLeftNeutral

[MultNatMonoidV] VerifiedMonoid Nat using MultNatSemiV, MultNatMonoid where
  monoidNeutralIsNeutralL = multOneRightNeutral
  monoidNeutralIsNeutralR = multOneLeftNeutral

[PlusZZMonoidV] VerifiedMonoid ZZ using PlusZZSemiV, PlusZZMonoid where
   monoidNeutralIsNeutralL = plusZeroRightNeutralZ
   monoidNeutralIsNeutralR = plusZeroLeftNeutralZ

[MultZZMonoidV] VerifiedMonoid ZZ using MultZZSemiV, MultZZMonoid where
  monoidNeutralIsNeutralL = multOneRightNeutralZ
  monoidNeutralIsNeutralR = multOneLeftNeutralZ

implementation VerifiedMonoid (List a) where
  monoidNeutralIsNeutralL = appendNilRightNeutral
  monoidNeutralIsNeutralR xs = Refl

interface (VerifiedMonoid a, Group a) => VerifiedGroup a where
  groupInverseIsInverseL : (l : a) -> l <+> inverse l = Algebra.neutral
  groupInverseIsInverseR : (r : a) -> inverse r <+> r = Algebra.neutral

VerifiedGroup ZZ using PlusZZMonoidV where
  groupInverseIsInverseL k = rewrite sym $ multCommutativeZ (NegS 0) k in
                             rewrite multNegLeftZ 0 k in
                             rewrite multOneLeftNeutralZ k in
                             plusNegateInverseLZ k
  groupInverseIsInverseR k = rewrite sym $ multCommutativeZ (NegS 0) k in
                             rewrite multNegLeftZ 0 k in
                             rewrite multOneLeftNeutralZ k in
                             plusNegateInverseRZ k

interface (VerifiedGroup a, AbelianGroup a) => VerifiedAbelianGroup a where
  abelianGroupOpIsCommutative : (l, r : a) -> l <+> r = r <+> l

VerifiedAbelianGroup ZZ where
  abelianGroupOpIsCommutative = plusCommutativeZ

interface (VerifiedAbelianGroup a, Ring a) => VerifiedRing a where
  ringOpIsAssociative   : (l, c, r : a) -> l <.> (c <.> r) = (l <.> c) <.> r
  ringOpIsDistributiveL : (l, c, r : a) -> l <.> (c <+> r) = (l <.> c) <+> (l <.> r)
  ringOpIsDistributiveR : (l, c, r : a) -> (l <+> c) <.> r = (l <.> r) <+> (c <.> r)

VerifiedRing ZZ where
  ringOpIsAssociative = multAssociativeZ
  ringOpIsDistributiveL = multDistributesOverPlusRightZ
  ringOpIsDistributiveR = multDistributesOverPlusLeftZ

interface (VerifiedRing a, RingWithUnity a) => VerifiedRingWithUnity a where
  ringWithUnityIsUnityL : (l : a) -> l <.> Algebra.unity = l
  ringWithUnityIsUnityR : (r : a) -> Algebra.unity <.> r = r

VerifiedRingWithUnity ZZ where
  ringWithUnityIsUnityL = multOneRightNeutralZ
  ringWithUnityIsUnityR = multOneLeftNeutralZ

interface JoinSemilattice a => VerifiedJoinSemilattice a where
  joinSemilatticeJoinIsAssociative : (l, c, r : a) -> join l (join c r) = join (join l c) r
  joinSemilatticeJoinIsCommutative : (l, r : a)    -> join l r = join r l
  joinSemilatticeJoinIsIdempotent  : (e : a)       -> join e e = e

interface MeetSemilattice a => VerifiedMeetSemilattice a where
  meetSemilatticeMeetIsAssociative : (l, c, r : a) -> meet l (meet c r) = meet (meet l c) r
  meetSemilatticeMeetIsCommutative : (l, r : a)    -> meet l r = meet r l
  meetSemilatticeMeetIsIdempotent  : (e : a)       -> meet e e = e

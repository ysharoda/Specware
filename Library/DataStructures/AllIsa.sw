%% This spec imports all the specs that get through Isabelle.  They may
%% contain sorrys but at least give legal Isabelle files.  (Actually,
%% this doesn't bother to import any morphisms, because their
%% obligations don't get imported.  So they should be tested
%% separately):

spec
  import Sets
  import Maps
  import Bags
  import Maps#Maps_extended
  import Stacks
  import Base
  import StructuredTypes
  import MapsAsSets#MapsAsSets
  import SetsAsBags#SetsAsBags
  import SetsAsMaps#SetsAsMaps
  import BagsAsMaps#BagsAsMaps
  import SetsAsBagMaps#SetsAsBagMaps
end-spec

use hyperast::{
    tree_gen,
    types::{self, ETypeStore, HyperAST, HyperASTShared, StoreRefAssoc},
};

#[derive(Default)]
pub struct PreparedQuerying<Q, HAST, Acc>(Q, std::marker::PhantomData<(HAST, Acc)>);

impl<'a, HAST, Acc> From<&'a crate::Query> for PreparedQuerying<&'a crate::Query, HAST, Acc> {
    fn from(value: &'a crate::Query) -> Self {
        Self(value, Default::default())
    }
}

impl<Q, HAST, Acc> std::ops::Deref for PreparedQuerying<Q, HAST, &Acc> {
    type Target = Q;

    fn deref(&self) -> &Self::Target {
        &self.0
    }
}

impl<HAST: HyperAST, Acc> tree_gen::Prepro<HAST> for PreparedQuerying<&crate::Query, HAST::TS, Acc>
where
    HAST::TS: ETypeStore,
{
    const USING: bool = false;

    fn preprocessing(
        &self,
        _ty: <HAST::TS as ETypeStore>::Ty2,
    ) -> Result<hyperast::scripting::Acc, String> {
        unimplemented!()
    }
}

impl<HAST, Acc> tree_gen::More<HAST> for PreparedQuerying<&crate::Query, HAST::TS, Acc>
where
    HAST: StoreRefAssoc,
    HAST::TS: 'static + Copy + ETypeStore + types::RoleStore<IdF = u16, Role = types::Role>,
    HAST::IdN: Copy,
    Acc: types::Typed<Type = <HAST::TS as ETypeStore>::Ty2>
        + tree_gen::WithRole<types::Role>
        + tree_gen::WithChildren<HAST::IdN>,
    for<'c> &'c Acc: tree_gen::WithLabel<L = &'c str>,
    for<'t> types::LendT<'t, HAST>: types::WithRoles,
    HAST::IdN: types::NodeId<IdN = HAST::IdN>,
{
    type Acc = Acc;
    const ENABLED: bool = true;
    fn match_precomp_queries(
        &self,
        stores: <HAST as StoreRefAssoc>::S<'_>,
        acc: &Acc,
        label: Option<&str>,
    ) -> tree_gen::PrecompQueries {
        if self.0.enabled_pattern_count() == 0 {
            return Default::default();
        }
        let pos = hyperast::position::StructuralPosition::empty();

        let cursor = crate::cursor_on_unbuild::TreeCursor::new(stores, acc, label, pos);
        let mut qcursor: crate::QueryCursor<
            '_,
            _,
            <crate::cursor_on_unbuild::Node<
                <HAST as StoreRefAssoc>::S<'_>,
                &Acc,
                <<HAST as StoreRefAssoc>::S<'_> as HyperASTShared>::Idx,
                hyperast::position::structural_pos::StructuralPosition<
                    <<HAST as StoreRefAssoc>::S<'_> as HyperASTShared>::IdN,
                    <<HAST as StoreRefAssoc>::S<'_> as HyperASTShared>::Idx,
                >,
                &str,
            > as crate::Cursor>::Node,
        > = self.0.matches_immediate(cursor); // TODO filter on height (and visibility?)
        let mut r = Default::default();
        while let Some(m) = qcursor.next() {
            assert!(m.pattern_index.to_usize() < 16);
            r |= 1 << m.pattern_index.to_usize() as u16;
        }
        r
    }
}

impl<HAST, Acc> tree_gen::PreproTSG<HAST> for PreparedQuerying<&crate::Query, HAST::TS, Acc>
where
    HAST: StoreRefAssoc,
    HAST::TS: 'static + Clone + ETypeStore + types::RoleStore<IdF = u16, Role = types::Role>,
    HAST::IdN: Copy,
    Acc: types::Typed<Type = <HAST::TS as ETypeStore>::Ty2>
        + tree_gen::WithRole<types::Role>
        + tree_gen::WithChildren<HAST::IdN>,
    for<'c> &'c Acc: tree_gen::WithLabel<L = &'c str>,
    for<'t> types::LendT<'t, HAST>: types::WithRoles,
    HAST::IdN: types::NodeId<IdN = HAST::IdN>,
{
    const GRAPHING: bool = false;
    fn compute_tsg(
        &self,
        _stores: <HAST as StoreRefAssoc>::S<'_>,
        _acc: &Acc,
        _label: Option<&str>,
    ) -> Result<usize, String> {
        Ok(0)
    }
}

import { useState } from 'react';
import { ArrowRight, Check, Heart, Minus, Plus, Truck } from 'lucide-react';
import { bangkokDay, defaultCompanion } from '../../lib/wanjai';
import { PickerDialog } from '../PickerDialog';
import { ProductArt } from '../WanjaiArtwork';
import { type WanjaiPageProps, PageIntro, Note, usePage } from './WanjaiShared';

const styles: Record<string, string[]> = {
  warm: ['amber', 'star'],
  soft: ['moon', 'rose'],
  cool: ['purple', 'crystal'],
};
export function WanjaiShop(p: WanjaiPageProps) {
  const { t, state, update, navigate } = p;
  const { data } = usePage(p);
  const [savedOnly, setSavedOnly] = useState(p.view === 'favorites');
  const [selected, setSelected] = useState<string | null>(null);
  const [stage, setStage] = useState<'detail' | 'checkout' | 'saved'>('detail');
  const [size, setSize] = useState('16 cm');
  const [quantity, setQuantity] = useState(1);
  const product = data.products.find((item) => item.id === selected);
  const taste = state.taste;
  const setTaste = (patch: Partial<typeof taste>) => update({ taste: { ...taste, ...patch } });
  const toggle = (id: string) =>
    update({
      favorites: state.favorites.includes(id)
        ? state.favorites.filter((row) => row !== id)
        : [...state.favorites, id],
    });
  const products = data.products.filter(
    (item) =>
      (taste.category === 'all' || item.type === taste.category) &&
      item.price <= taste.budget &&
      (taste.style === 'any' || styles[taste.style]?.includes(item.id)) &&
      (!savedOnly || state.favorites.includes(item.id)),
  );
  if (p.view === 'orders')
    return (
      <div className="space-y-4">
        <PageIntro title={t.j_orders} sub={t.w_paymentNote} />
        {!state.demo_orders.length ? (
          <p className="jy-card jy-copy">{t.j_emptyOrders}</p>
        ) : (
          [...state.demo_orders].reverse().map((order) => {
            const item = data.products.find((row) => row.id === order.product)!;
            return (
              <article key={order.id} className="jy-card">
                <div className="flex items-center gap-4">
                  <div
                    className="h-20 w-20 shrink-0 overflow-hidden rounded-xl"
                    style={{ background: item.bg }}
                  >
                    <ProductArt {...item} title={item.name} />
                  </div>
                  <div>
                    <p className="text-[15px] leading-7">{item.name}</p>
                    <p className="mt-2 text-xs text-muted">
                      {order.day} · {order.size === 'standard' ? item.category : order.size} ×{' '}
                      {order.quantity}
                    </p>
                    <p className="mt-2 text-sm text-accent">
                      ฿{order.total} · {t.w_priceNote}
                    </p>
                  </div>
                </div>
                <p className="mt-4 border-t border-line pt-3 text-xs leading-6 text-muted">
                  {t.w_paymentNote}
                </p>
              </article>
            );
          })
        )}
        <button className="jy-primary w-full" onClick={() => navigate('shop')}>
          {t.j_backShop}
          <ArrowRight size={16} />
        </button>
      </div>
    );
  return (
    <div data-testid="jy-shop-page">
      <PageIntro
        title={p.view === 'favorites' ? t.w_favorites : t.j_shopTitle}
        sub={t.w_shopIntro}
      />
      <details
        className="mb-5 rounded-[17px] border border-[#daceb9] bg-[#fffaf0]"
        data-testid="taste-panel"
      >
        <summary className="flex cursor-pointer items-center justify-between gap-3 p-4 text-sm">
          <span>
            {t.j_tasteTitle}
            <small className="ml-3 text-[#ac9472]">{t.j_optional}</small>
          </span>
          <span>＋</span>
        </summary>
        <div className="space-y-4 border-t border-line p-4">
          <fieldset>
            <legend className="mb-2 text-xs text-[#92754f]">{t.j_style}</legend>
            <div className="flex flex-wrap gap-2">
              {(['any', 'warm', 'soft', 'cool'] as const).map((style) => (
                <button
                  key={style}
                  aria-pressed={taste.style === style}
                  className={`rounded-xl border px-3 py-2 text-xs ${taste.style === style ? 'border-primary bg-[#eddfcc] text-accent' : 'border-[#ddcfb8]'}`}
                  onClick={() => setTaste({ style })}
                >
                  {
                    t[
                      (
                        {
                          any: 'j_anyStyle',
                          warm: 'j_warm',
                          soft: 'j_soft',
                          cool: 'j_cool',
                        } as const
                      )[style]
                    ]
                  }
                </button>
              ))}
            </div>
          </fieldset>
          <label className="block text-xs text-[#92754f]" htmlFor="shop-budget">
            {t.w_budget}
          </label>
          <select
            id="shop-budget"
            className="field"
            value={taste.budget}
            onChange={(e) => setTaste({ budget: Number(e.target.value) })}
          >
            {[300, 500, 1000].map((amount) => (
              <option value={amount} key={amount}>
                ฿{amount}
              </option>
            ))}
          </select>
          <button
            className="text-xs text-accent underline underline-offset-4"
            onClick={() => update({ taste: { ...defaultCompanion.taste } })}
          >
            {t.j_resetTaste}
          </button>
          <p className="text-[11px] leading-6 text-muted">{t.j_tasteNote}</p>
        </div>
      </details>
      <div className="mb-4 flex flex-wrap gap-2">
        {(['all', 'bracelet', 'crystal', 'charm'] as const).map((category) => (
          <button
            key={category}
            aria-pressed={taste.category === category}
            className={`min-h-10 rounded-xl border px-3 text-xs ${taste.category === category ? 'border-primary bg-primary text-white' : 'border-[#dccfb8] text-[#8a714d]'}`}
            onClick={() => setTaste({ category })}
          >
            {t[`w_${category}`]}
          </button>
        ))}
        <button
          aria-pressed={savedOnly}
          className="ml-auto px-1 text-xs text-accent"
          onClick={() => setSavedOnly(!savedOnly)}
        >
          {t.w_favorites}
        </button>
      </div>
      <p className="mb-5 flex items-center gap-2 text-[11px] text-[#9e8a6c]">
        <Truck size={15} />
        {t.w_productNote}
      </p>
      <div className="grid grid-cols-2 gap-x-3 gap-y-6">
        {products.map((item) => (
          <article key={item.id} className="min-w-0">
            <div className="relative">
              <button
                aria-label={item.name}
                className="block h-[166px] w-full overflow-hidden rounded-[17px]"
                style={{ backgroundColor: item.bg }}
                onClick={() => {
                  setSelected(item.id);
                  setStage('detail');
                  setQuantity(1);
                  setSize('16 cm');
                }}
              >
                <ProductArt {...item} title={item.name} />
              </button>
              <button
                aria-label={`${state.favorites.includes(item.id) ? t.w_unfavorite : t.w_favorite} ${item.name}`}
                aria-pressed={state.favorites.includes(item.id)}
                className="absolute right-2 top-2 grid h-8 w-8 place-items-center rounded-full bg-panel/90 text-accent"
                onClick={() => toggle(item.id)}
              >
                <Heart
                  size={16}
                  fill={state.favorites.includes(item.id) ? 'currentColor' : 'none'}
                />
              </button>
            </div>
            <button
              className="mt-3 text-left text-[13px] leading-6"
              onClick={() => {
                setSelected(item.id);
                setStage('detail');
                setQuantity(1);
              }}
            >
              {item.name}
            </button>
            <p className="mt-1 text-[11px] leading-6 text-[#a18a66]">{item.tag}</p>
            <div className="mt-2 flex items-center justify-between gap-2">
              <span className="font-display text-xl text-[#8d3a31]">฿{item.price}</span>
              <small className="text-[9px] text-muted">{t.w_priceNote}</small>
            </div>
          </article>
        ))}
      </div>
      {!products.length && (
        <div role="status" className="jy-card my-5">
          <p className="jy-copy">{t.w_noProducts}</p>
          <button
            className="jy-outline mt-4 w-full"
            onClick={() => {
              update({ taste: { ...defaultCompanion.taste } });
              setSavedOnly(false);
            }}
          >
            {t.j_resetTaste}
          </button>
        </div>
      )}
      <section className="mt-7 rounded-[18px] bg-[#e8dfcc] p-5">
        <h2 className="text-[18px] leading-8">{t.j_shopStory}</h2>
        <p className="jy-copy mt-2">{t.j_tasteNote}</p>
      </section>
      {product && (
        <PickerDialog
          title={
            stage === 'saved' ? t.j_orderSaved : stage === 'checkout' ? t.j_checkout : product.name
          }
          t={t}
          confirmLabel={
            stage === 'detail'
              ? t.j_checkout
              : stage === 'checkout'
                ? t.j_simulateOrder
                : t.pickerDone
          }
          onCancel={() => {
            if (stage === 'checkout') setStage('detail');
            else setSelected(null);
          }}
          onConfirm={() => {
            if (stage === 'detail') setStage('checkout');
            else if (stage === 'checkout') {
              update({
                demo_orders: [
                  ...state.demo_orders,
                  {
                    id: crypto.randomUUID(),
                    product: product.id,
                    size: product.type === 'bracelet' ? size : 'standard',
                    quantity,
                    total: product.price * quantity,
                    day: bangkokDay(),
                  },
                ].slice(-20),
              });
              setStage('saved');
            } else setSelected(null);
          }}
        >
          {stage === 'saved' ? (
            <div className="py-4 text-center">
              <Check size={38} className="mx-auto mb-4 text-[#73816b]" />
              <p className="jy-copy">{t.w_paymentNote}</p>
              <button
                className="jy-outline mt-5"
                onClick={() => {
                  setSelected(null);
                  navigate('orders');
                }}
              >
                {t.j_orders}
                <ArrowRight size={15} />
              </button>
            </div>
          ) : (
            <>
              <div
                className="mb-4 h-40 overflow-hidden rounded-2xl"
                style={{ backgroundColor: product.bg }}
              >
                <ProductArt {...product} title={product.name} />
              </div>
              <p className="mb-3 font-display text-2xl text-accent">
                ฿{product.price * quantity}
                <small className="ml-2 font-sans text-xs text-muted">{t.w_priceNote}</small>
              </p>
              <p className="jy-copy mb-4">{product.desc}</p>
              {stage === 'detail' ? (
                <>
                  {product.type === 'bracelet' && (
                    <fieldset className="mb-5">
                      <legend className="mb-3 text-sm">{t.j_size}</legend>
                      <div className="flex gap-2">
                        {['14 cm', '16 cm', '18 cm'].map((v) => (
                          <button
                            key={v}
                            aria-pressed={size === v}
                            className={`jy-outline flex-1 !px-2 ${size === v ? '!border-primary !bg-surface !text-accent' : ''}`}
                            onClick={() => setSize(v)}
                          >
                            {v}
                          </button>
                        ))}
                      </div>
                    </fieldset>
                  )}
                  <div className="mb-5 flex items-center gap-4">
                    <span className="mr-auto text-sm">{t.j_quantity}</span>
                    <button
                      className="jy-icon border border-line"
                      aria-label={`${t.j_quantity} −`}
                      disabled={quantity === 1}
                      onClick={() => setQuantity(quantity - 1)}
                    >
                      <Minus size={16} />
                    </button>
                    <span className="text-sm" aria-live="polite">
                      {quantity}
                    </span>
                    <button
                      className="jy-icon border border-line"
                      aria-label={`${t.j_quantity} +`}
                      disabled={quantity === 9}
                      onClick={() => setQuantity(quantity + 1)}
                    >
                      <Plus size={16} />
                    </button>
                  </div>
                  <section className="rounded-xl border border-line bg-canvas p-4">
                    <h3 className="mb-2 text-sm">{t.w_productDetail}</h3>
                    <p className="text-xs leading-7 text-muted">{product.material}</p>
                  </section>
                </>
              ) : (
                <div className="my-5 rounded-xl border border-line p-4 text-sm leading-8">
                  <p>
                    {product.type === 'bracelet' ? size : product.category} × {quantity}
                  </p>
                  <p>฿{product.price * quantity}</p>
                </div>
              )}
              <Note>{t.w_paymentNote}</Note>
            </>
          )}
        </PickerDialog>
      )}
    </div>
  );
}

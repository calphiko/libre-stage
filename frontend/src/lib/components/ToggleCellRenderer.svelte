<script lang="ts">
        let { checked = $bindable(false), onChange }: {
          checked: boolean;
          onChange?: (checked: boolean) => void
        } = $props();

        function toggle() {
          checked = !checked;
          onChange?.(checked);
        }
      </script>

      <div style="display:flex;align-items:center;height:100%;padding:0 8px;">
        <button
          onclick={toggle}
          style="width:44px;height:24px;border-radius:12px;border:none;cursor:pointer;background:{checked ? '#22c55e' : '#6b7280'};position:relative;transition:background 0.2s;"
        >
          <span
            style="position:absolute;top:2px;left:{checked ? '22px' : '2px'};width:20px;height:20px;border-radius:50%;background:white;transition:left 0.2s;display:block;"
          ></span>
        </button>
      </div>
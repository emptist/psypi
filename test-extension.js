// Plain JavaScript extension (no TypeScript!)
export default function (pi) {
  pi.registerTool({
    name: "test-js-extension",
    description: "Test if Pi loads .js files directly",
    parameters: {},
    execute: async (args, ctx) => {
      ctx.ui.notify("✅ Pi loaded .js extension directly!");
      return "Success!";
    }
  });
}

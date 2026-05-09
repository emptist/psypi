Based on the Pi documentation and psypi's       
 setup, here's how to use and extend Pi:         
                                                 
 ─────────────────────────────────────────────── 
                                                 
 📖 Using Pi                                     
                                                 
 ### Basic Usage                                 
                                                 
 ```bash                                         
   pi                    # Interactive mode      
 (TUI)                                           
   pi -p "prompt"        # Print mode            
 (non-interactive)                               
   pi --mode json         # JSON output mode     
   pi --mode rpc          # RPC mode for process 
 integration                                     
 ```                                             
                                                 
 ### Key Interactive Commands                    
                                                 
 ┌───────────┬─────────────────────────────────┐ 
 │ Command   │ Description                     │ 
 ├───────────┼─────────────────────────────────┤ 
 │ /model    │ Switch AI models                │ 
 ├───────────┼─────────────────────────────────┤ 
 │ /resume   │ Switch to previous session      │ 
 ├───────────┼─────────────────────────────────┤ 
 │ /new      │ Start new session               │ 
 ├───────────┼─────────────────────────────────┤ 
 │ /tree     │ Navigate session branches       │ 
 ├───────────┼─────────────────────────────────┤ 
 │ /reload   │ Reload extensions, skills,      │ 
 │           │ prompts                         │ 
 ├───────────┼─────────────────────────────────┤ 
 │ /settings │ Change thinking level, theme    │ 
 ├───────────┼─────────────────────────────────┤ 
 │ !command  │ Run bash, send output to LLM    │ 
 ├───────────┼─────────────────────────────────┤ 
 │ @file     │ Reference files in prompt       │ 
 └───────────┴─────────────────────────────────┘ 
                                                 
 ### Pi Package Management                       
                                                 
 ```bash                                         
   pi install npm:@foo/pi-tools     # Install    
 package                                         
   pi list                          # List       
 installed packages                              
   pi update                        # Update pi  
 and packages                                    
   pi remove npm:@foo/pi-tools      # Uninstall  
   pi config                        #            
 Enable/disable resources                        
 ```                                             
                                                 
 ─────────────────────────────────────────────── 
                                                 
 🛠️ Extending Pi (Extensions)                    
                                                 
 Extensions are TypeScript modules that hook     
 into Pi's lifecycle to add custom tools,        
 commands, UI, and event handlers.               
                                                 
 ### Quick Start Extension                       
                                                 
 Create ~/.pi/agent/extensions/my-ext.ts         
 (global) or .pi/extensions/my-ext.ts            
 (project-local):                                
                                                 
 ```typescript                                   
   import type { ExtensionAPI } from             
 "@mariozechner/pi-coding-agent";                
   import { Type } from "typebox";               
                                                 
   export default function (pi: ExtensionAPI) {  
     // 1. React to events                       
     pi.on("session_start", async (_event, ctx)  
 => {                                            
       ctx.ui.notify("Extension loaded!",        
 "info");                                        
     });                                         
                                                 
     // 2. Block/modify tool calls               
     pi.on("tool_call", async (event, ctx) => {  
       if (event.toolName === "bash" &&          
 event.input.command?.includes("rm -rf")) {      
         const ok = await                        
 ctx.ui.confirm("Dangerous!", "Allow rm -rf?");  
         if (!ok) return { block: true, reason:  
 "Blocked" };                                    
       }                                         
     });                                         
                                                 
     // 3. Register custom tool                  
     pi.registerTool({                           
       name: "greet",                            
       description: "Greet someone",             
       parameters: Type.Object({                 
         name: Type.String(),                    
       }),                                       
       async execute(_id, params) {              
         return { content: [{ type: "text",      
 text: `Hello, ${params.name}!` }] };            
       },                                        
     });                                         
                                                 
     // 4. Register command                      
     pi.registerCommand("hello", {               
       description: "Say hello",                 
       handler: async (args, ctx) => {           
         ctx.ui.notify(`Hello ${args ||          
 "world"}!`, "info");                            
       },                                        
     });                                         
   }                                             
 ```                                             
                                                 
 Reload with /reload in Pi TUI.                  
                                                 
 ─────────────────────────────────────────────── 
                                                 
 🎯 Key Extension Capabilities                   
                                                 
 ┌───────────┬───────────────────┬─────────────┐ 
 │ Capabilit │ Method            │ Use Case    │ 
 │ y         │                   │             │ 
 ├───────────┼───────────────────┼─────────────┤ 
 │ Custom    │ pi.registerTool() │ Add new     │ 
 │ tools     │                   │ LLM-callabl │ 
 │           │                   │ e tools     │ 
 ├───────────┼───────────────────┼─────────────┤ 
 │ Commands  │ pi.registerComman │ Add         │ 
 │           │ d()               │ /command to │ 
 │           │                   │ TUI         │ 
 ├───────────┼───────────────────┼─────────────┤ 
 │ Event     │ pi.on("event",    │ Intercept   │ 
 │ hooks     │ handler)          │ lifecycle   │ 
 │           │                   │ events      │ 
 ├───────────┼───────────────────┼─────────────┤ 
 │ Shortcuts │ pi.registerShortc │ Add         │ 
 │           │ ut()              │ keyboard    │ 
 │           │                   │ shortcuts   │ 
 ├───────────┼───────────────────┼─────────────┤ 
 │ Custom UI │ ctx.ui.*          │ Notificatio │ 
 │           │                   │ ns,         │ 
 │           │                   │ prompts,    │ 
 │           │                   │ widgets     │ 
 ├───────────┼───────────────────┼─────────────┤ 
 │ State     │ pi.appendEntry()  │ Persist     │ 
 │           │                   │ state       │ 
 │           │                   │ across      │ 
 │           │                   │ reloads     │ 
 └───────────┴───────────────────┴─────────────┘ 
                                                 
 ─────────────────────────────────────────────── 
                                                 
 📅 Important Events to Hook                     
                                                 
 ┌────────────────────┬──────────┬─────────────┐ 
 │ Event              │ When     │ Common Use  │ 
 │                    │ Fires    │             │ 
 ├────────────────────┼──────────┼─────────────┤ 
 │ session_start      │ Session  │ Initialize  │ 
 │                    │ loads    │ state       │ 
 ├────────────────────┼──────────┼─────────────┤ 
 │ tool_call          │ Before   │ Can block,  │ 
 │                    │ tool     │ modify args │ 
 │                    │ runs     │             │ 
 ├────────────────────┼──────────┼─────────────┤ 
 │ tool_result        │ After    │ Modify      │ 
 │                    │ tool     │ results,    │ 
 │                    │ runs     │ trigger     │ 
 │                    │          │ actions     │ 
 ├────────────────────┼──────────┼─────────────┤ 
 │ turn_end           │ After    │ Periodic    │ 
 │                    │ LLM turn │ checks      │ 
 ├────────────────────┼──────────┼─────────────┤ 
 │ session_shutdown   │ Session  │ Cleanup     │ 
 │                    │ exits    │ intervals   │ 
 ├────────────────────┼──────────┼─────────────┤ 
 │ before_agent_start │ Before   │ Inject      │ 
 │                    │ LLM call │ context,    │ 
 │                    │          │ modify      │ 
 │                    │          │ system      │ 
 │                    │          │ prompt      │ 
 └────────────────────┴──────────┴─────────────┘ 
                                                 
 ─────────────────────────────────────────────── 
                                                 
 🏗️ Extension Locations                          
                                                 
 ┌──────────────────────────────┬──────────────┐ 
 │ Location                     │ Scope        │ 
 ├──────────────────────────────┼──────────────┤ 
 │ ~/.pi/agent/extensions/*.ts  │ Global (all  │ 
 │                              │ projects)    │ 
 ├──────────────────────────────┼──────────────┤ 
 │ ~/.pi/agent/extensions/*/ind │ Global       │ 
 │ ex.ts                        │ (directory)  │ 
 ├──────────────────────────────┼──────────────┤ 
 │ .pi/extensions/*.ts          │ Project-loca │ 
 │                              │ l            │ 
 ├──────────────────────────────┼──────────────┤ 
 │ .pi/extensions/*/index.ts    │ Project-loca │ 
 │                              │ l            │ 
 │                              │ (directory)  │ 
 └──────────────────────────────┴──────────────┘ 
                                                 
 Extensions auto-discover from these paths and   
 hot-reload with /reload.                        
                                                 
 ─────────────────────────────────────────────── 
                                                 
 📦 For psypi Project (Your Current Project)     
                                                 
 psypi uses Pi as its runtime. Key integration   
 points:                                         
                                                 
 1. Extension location: .pi/extensions/ in psypi 
 project                                         
 2. Uses events to hook into psypi workflows     
 (meetings, tasks, issues)                       
 3. Follows rules in AGENTS.md:                  
     - Use kernel.piSessionID() for session ID   
     - Use                                       
 AgentIdentityService.getResolvedIdentity() for  
 agent ID                                        
     - Report issues first with psypi issue-add  
     - Use psypi tools, not raw psql             
                                                 
 ### Example: psypi Meeting Monitor Extension    
                                                 
 See docs/AI_GUIDE-requesting-pi-extensions.md   
 for a full example of requesting Pi to build an 
 extension that monitors meeting opinions via    
 tool_result event.                              
                                                 
 ─────────────────────────────────────────────── 
                                                 
 📚 Resources                                    
                                                 
 ┌────────────┬────────────────────────────────┐ 
 │ Resource   │ Path                           │ 
 ├────────────┼────────────────────────────────┤ 
 │ Pi README  │ /opt/homebrew/lib/node_modules │ 
 │            │ /@mariozechner/pi-coding-agent │ 
 │            │ /README.md                     │ 
 ├────────────┼────────────────────────────────┤ 
 │ Extension  │ /opt/homebrew/lib/node_modules │ 
 │ Docs       │ /@mariozechner/pi-coding-agent │ 
 │            │ /docs/extensions.md            │ 
 ├────────────┼────────────────────────────────┤ 
 │ Example    │ /opt/homebrew/lib/node_modules │ 
 │ Extensions │ /@mariozechner/pi-coding-agent │ 
 │            │ /examples/extensions/          │ 
 ├────────────┼────────────────────────────────┤ 
 │ psypi      │ /Users/jk/gits/hub/tools_ai/ps │ 
 │ Extension  │ ypi/docs/AI_GUIDE-requesting-p │ 
 │ Guide      │ i-extensions.md                │ 
 └────────────┴────────────────────────────────┘ 
                                                 
 Want me to help you create a specific Pi        
 extension for psypi? Just describe what you     
 want to automate! 🚀                            


can you create a Pi extension in Gleam          
 language?                                       
                                                 

 The user is asking if I can create a Pi         
 extension in Gleam language. Let me think about 
 this:                                           
                                                 
 1. Pi extensions are TypeScript modules that    
 export a default function receiving             
 ExtensionAPI                                    
 2. Gleam is a language that compiles to Erlang  
 or JavaScript                                   
 3. Pi extensions are loaded via jiti which      
 supports TypeScript natively                    
 4. Gleam can compile to JavaScript, so          
 theoretically it could work                     
                                                 
 However, there are several challenges:          
 - Pi's extension system expects                 
 TypeScript/JavaScript modules                   
 - Gleam compiles to JS but the module format    
 and exports might not be compatible             
 - The type system and FFI (Foreign Function     
 Interface) would need to match Pi's             
 ExtensionAPI                                    
 - Gleam is functional and uses different        
 patterns than TypeScript                        
                                                 
 Let me check:                                   
 1. Can Gleam compile to JS that Pi's jiti can   
 load?                                           
 2. Can Gleam interoperate with TypeScript types 
 from @mariozechner/pi-coding-agent?             
 3. What would the Gleam code look like?         
                                                 
 From what I know about Gleam:                   
 - It can compile to JavaScript                  
 - It has FFI to call JavaScript functions       
 - But the module system and how exports work    
 might be tricky                                 
                                                 
 Let me think about the feasibility:             
 - Pi loads extensions via jiti, which handles   
 .ts, .js, .mjs files                            
 - Gleam compiles to JS, but the output format   
 might not be directly loadable                  
 - Even if it compiles, the Gleam FFI would need 
 to properly interface with Pi's ExtensionAPI    
                                                 
 This is an interesting question. Let me provide 
 a realistic answer:                             
                                                 
 Short answer: Technically possible but highly   
 impractical right now because:                  
 1. Pi expects TypeScript/JS with specific       
 import patterns                                 
 2. Gleam's JS output might not be directly      
 compatible with jiti                            
 3. The FFI needed to interact with Pi's APIs    
 would be extensive                              
 4. No existing examples of Gleam Pi extensions  
 5. The psypi project already uses Gleam for     
 core logic (380 lines in gleam/psypi_core)      
                                                 
 I'll explore a potential approach that          
 leverages the existing Gleam core while finding 
 a way to interface with Pi's extension system.  
 The key will be creating a compatible           
 JavaScript wrapper that can bridge the          
 Gleam-compiled code with Pi's extension loading 
 mechanism.                                      

 Short answer: Not directly - Pi extensions      
 require TypeScript/JavaScript that uses Pi's    
 ExtensionAPI types, but there's a workaround    
 using Gleam compiled to JS.                     
                                                 
 Let me explain the challenges and a possible    
 approach:                                       
                                                 
 ─────────────────────────────────────────────── 
                                                 
 🚫 Why Not Pure Gleam?                          
                                                 
 1. Pi's extension loader uses jiti which        
 supports .ts, .js, .mts, .mjs - not .gleam      
 2. TypeScript type imports - Pi extensions      
 import types from @mariozechner/pi-coding-agent 
  which Gleam can't directly use                 
 3. API shape - Gleam compiled JS uses           
 Erlang-style exports, not Node.js module        
 exports                                         
                                                 
 ─────────────────────────────────────────────── 
                                                 
 ✅ Workaround: Gleam Core + TypeScript Wrapper  
                                                 
 Since psypi already uses Gleam (380 lines in    
 gleam/psypi_core), here's the pattern:          
                                                 
 ### Architecture                                
                                                 
 ```                                             
   Gleam logic (.gleam) → Compile to JS → Import 
 in TS extension → Register with Pi              
 ```                                             
                                                 
 ### Step 1: Write Gleam Module                  
                                                 
 ```gleam                                        
   //                                            
 gleam/psypi_core/extensions/meeting_monitor.gle 
 am                                              
   import gleam/dynamic                          
   import gleam/result                           
                                                 
   pub fn handle_tool_result(tool_name: String,  
 command: String) -> String {                    
     case tool_name {                            
       "bash" if string.contains(command, "psypi 
 meeting opinion") -> {                          
         "detected_meeting_opinion"              
       }                                         
       _ -> "no_action"                          
     }                                           
   }                                             
 ```                                             
                                                 
 ### Step 2: Compile Gleam to JS                 
                                                 
 ```bash                                         
   cd gleam/psypi_core                           
   gleam build  # Outputs to build/              
 ```                                             
                                                 
 ### Step 3: TypeScript Wrapper Extension        
                                                 
 ```typescript                                   
   // .pi/extensions/meeting-monitor.ts          
   import type { ExtensionAPI } from             
 "@mariozechner/pi-coding-agent";                
                                                 
   // Import compiled Gleam JS (psypi already    
 does this in gleam-bridge.ts)                   
   import { Psym } from                          
 "../../gleam/psypi_core/build/dev/javascript/ps 
 ypi_core/psypi_core.mjs";                       
                                                 
   export default function (pi: ExtensionAPI) {  
     pi.on("tool_result", async (event, ctx) =>  
 {                                               
       // Call Gleam function via FFI bridge     
       const action = Psym.handle_tool_result(   
         event.toolName,                         
         JSON.stringify(event.input)             
       );                                        
                                                 
       if (action ===                            
 "detected_meeting_opinion") {                   
         ctx.ui.notify("Meeting opinion          
 detected!", "info");                            
       }                                         
     });                                         
   }                                             
 ```                                             
                                                 
 ─────────────────────────────────────────────── 
                                                 
 🏗️ Current psypi Gleam Integration              
                                                 
 psypi already bridges Gleam and TypeScript via  
 src/common/gleam-bridge.ts:                     
                                                 
 ```typescript                                   
   // src/common/gleam-bridge.ts (13 lines)      
   export {                                      
     Psym,                                       
     // ... other Gleam modules                  
   } from                                        
 '../../gleam/psypi_core/build/dev/javascript/ps 
 ypi_core/psypi_core.mjs';                       
 ```                                             
                                                 
 ─────────────────────────────────────────────── 
                                                 
 🎯 Recommendation                               
                                                 
 For psypi extensions, use the hybrid approach:  
                                                 
 1. Core logic in Gleam (like review.gleam,      
 meeting.gleam)                                  
 2. Pi extension shell in TypeScript (thin       
 wrapper)                                        
 3. Import Gleam via bridge (already working in  
 psypi)                                          
                                                 
 ### Example: Meeting Monitor Extension          
                                                 
 Want me to create:                              
 1. A Gleam module                               
 gleam/psypi_core/extensions/monitor.gleam with  
 logic?                                          
 2. A TypeScript wrapper                         
 .pi/extensions/meeting-monitor.ts that imports  
 it?                                             
                                                 
 This follows psypi's pattern: Gleam for logic,  
 TypeScript for Pi integration! 🚀               

─────────────────────────────────────────────────
                                                 
─────────────────────────────────────────────────
~/gits/hub/tools_ai/psypi (detached)
↑86k ↓3.5k R6.4k 24.4%/131k (auto)  tencent/hy3-p

import { defaultCategories } from "../apps/web/src/lib/firebase/defaults";

const mosqueId = process.argv[2] || "demo-mosque";
const uid = process.argv[3] || "demo-owner";

console.log(JSON.stringify(defaultCategories(mosqueId, uid), null, 2));

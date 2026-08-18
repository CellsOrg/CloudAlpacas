declare module "@salesforce/apex/FanDetailController.getFanSummary" {
  export default function getFanSummary(param: {fanId: any}): Promise<any>;
}
declare module "@salesforce/apex/FanDetailController.getRecommendedActions" {
  export default function getRecommendedActions(param: {fanId: any}): Promise<any>;
}
declare module "@salesforce/apex/FanDetailController.markActionExecuted" {
  export default function markActionExecuted(param: {recommendationId: any}): Promise<any>;
}
declare module "@salesforce/apex/FanDetailController.getFanTimeline" {
  export default function getFanTimeline(param: {fanId: any}): Promise<any>;
}
